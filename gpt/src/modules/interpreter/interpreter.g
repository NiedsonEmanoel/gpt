/*
 *   Copyright (C) 2003-2006 by Thiago Silva                               *
 *   thiago.silva@kdemal.net                                               *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
                                                                           */


header {
   #include "PortugolAST.hpp"
//   #include "SemanticEval.hpp"
   #include "SymbolTable.hpp"
   #include "InterpreterEval.hpp"
   #include <string>
// 
//   #include <list>
//   
   using namespace std;

}
//-------------------------------------------------------------------------------

options {
  language="Cpp";
}

class InterpreterWalker extends TreeParser;
options {
  importVocab=Portugol;  // use vocab generated by lexer
  ASTLabelType="RefPortugolAST";
  noConstructors=true;
  genHashLines=false;//no #line
}

{  
  public:
    class ReturnException {};

    InterpreterWalker(SymbolTable& st, string host, int port)
      : interpreter(st, host, port) {    }

  private:

    InterpreterEval interpreter;

    RefPortugolAST topnode;


    string parseLiteral(string str) {
      string::size_type idx = 0;
      char c;
      while((idx = str.find('\\', idx)) != string::npos) {
        switch(str[idx+1]) {
          case 'n':
            c = '\n';
            break;
          case 't':
            c = '\t';
            break;
          case 'r':
            c = '\r';
            break;
          case '\\':
            c = '\\';
            break;
          case '\'':
            c = '\'';
            break;
          case '"':
            c = '"';
            break;
          default:
            c = str[idx+1];
        }
        str.replace(idx, 2, 1, c);
        idx++;
      }
      return str;
    }

    string parseChar(string str) {
      stringstream ret;
      /*
        ''    => 0
        'a'   => a
        '\t'  => \t
        '\n'  => \n
        '\r'  => \r
        '\i'  => i
      */
      if(str[0] == '\\') {
        switch(str[1]) {
          case 't':
            ret << (int) '\t';
            break;
          case 'n':
            ret << (int)'\n';
            break;
          case 'r':
            ret << (int) '\r';
            break;
          default:
            ret << (int)str[1];
        }
        return ret.str();
      } else {
				ret << (int) str[0];
        return ret.str();
      }      
    }

    RefPortugolAST getFunctionNode(const string& name) {
      RefPortugolAST node = topnode;
      while(node->getText() != name) {
        node = node->getNextSibling();
      }
      return node;
    }
}


/****************************** TREE WALKER *********************************************/

/*
 ( algoritmo teste ) 
  ( vari�veis ( primitive! inteiro x ) ) 
  ( in�cio ( := x 10 ) ( fcall! f x 1 ) ( para x 1 10 ( fcall! imprima x ) ) ) 
  ( f ( primitive! inteiro z ) ( primitive! inteiro r ) 
    ( vari�veis! ( primitive! caractere c ) ) 
    ( in�cio ( se ( < z 1 ) ( := c 1 ) ( retorne null! ) sen�o ( := c 2 ) ( fcall! f ( - z 1 ) r ) ) ( := c 3 ) ) 
  )

*/
algoritmo
{
  topnode = _t;
  interpreter.init(_t->getFilename());  
  _t = _t->getNextSibling();
  if(_t->getType() == T_KW_VARIAVEIS) {
    _t = _t->getNextSibling(); //pula declaracao de algoritmo e variaveis
  }
}
  : inicio    
  ;

inicio
  : #(t:T_KW_INICIO (stm)*)
      {interpreter.nextCmd(t->getFilename(), t->getEndLine());}
  ;

stm
{
  ExprValue retToDevNull;
  interpreter.nextCmd(static_cast<RefPortugolAST>(_t->getFirstChild())->getFilename(), _t->getLine());  
}
  : stm_attr
  | retToDevNull=fcall
  | stm_ret
  | stm_se
  | stm_enquanto
  | stm_para
  ;

stm_attr
{
  ExprValue v;
  LValue l;
}
  : #(t:T_ATTR
      l=lvalue
      v=expr
    )
    {interpreter.execAttribution(l, v);}
  ;

lvalue returns [LValue l]
{
  ExprValue e;
}
  : #(id:T_IDENTIFICADOR {l.name = id->getText();}
      (
        e=expr {l.addMatrixIndex(e);}
      )*
    )
  ;

fcall returns [ExprValue v]
{
  list<ExprValue> args;
  ExprValue e;
}
  : #(TI_FCALL id:T_IDENTIFICADOR
      (
        e=expr
        {args.push_back(e);}
      )*
    )
    {
      if(interpreter.isBuiltInFunction(id->getText())) {
        v = interpreter.execBuiltInFunction(id->getText(), args);
      } else {
        RefPortugolAST current = _t; //saves current state

        RefPortugolAST fnode   = getFunctionNode(id->getText()); //gets the function node

        try {
          func_decls(fnode, args, id->getLine());                  //executes
        } catch(ReturnException& e) {   }

        v = interpreter.getReturnExprValue();
      }
    }
  ;

stm_ret
{ExprValue etype;}
  : #(r:T_KW_RETORNE (TI_NULL|etype=expr))
    {
      interpreter.setReturnExprValue(etype);
      throw ReturnException();
    }
  ;

stm_se
{
  ExprValue e;
  bool exec = false;
}
  : #(se:T_KW_SE
      e=expr   {exec = e.ifTrue();} 

      conditional_statements[exec]
      {
        if(!exec) {
          while((_t != antlr::nullAST) && (_t->getType() != T_KW_SENAO)) {
            _t = _t->getNextSibling();
          }
        }
      }

      (T_KW_SENAO
        conditional_statements[!exec]
      )?
    )
  ;

conditional_statements [bool doIt]
  : {doIt}? (stm)*
  | /* empty */
  ;

  exception
  catch[...] {
    //nothing (doIt throws if false...)
  }

stm_enquanto
{
  ExprValue e;
  bool exec;
  RefPortugolAST exprNode, first_stm, stmNode;
}
  : #(enq:T_KW_ENQUANTO
      {exprNode = _t;} e=expr {exec=e.ifTrue();} 
      {
        stmNode = first_stm = _t;
        
        while(exec) {
          while(stmNode != antlr::nullAST) {
            stm(stmNode);
            stmNode = stmNode->getNextSibling();
          }
          exec = expr(exprNode).ifTrue();
          stmNode = first_stm;
        }
        _t = _retTree;
      }
    )
  ;

stm_para
{
  ExprValue de, ate;
  LValue lv;
  int ps;
  RefPortugolAST ateNode, first_stm, stmNode;
}
  : #(para:T_KW_PARA
        lv=lvalue
        de=expr   {interpreter.execAttribution(lv, de);}
          {ateNode = _t;}
        ate=expr

        //(ps=passo)?

        {
          if(_t && (_t->getType() == T_KW_PASSO)) {
            ps=passo(_t);
            _t = _retTree;
          } else {
            ps = 1;
          }

          stmNode = first_stm = _t;

          while(true) {
            if(ps > 0) {
              if(!interpreter.execLowerEq(lv, ate)) break;
            } else {
              if(!interpreter.execBiggerEq(lv, ate)) break;
            }
            while(stmNode != antlr::nullAST) {
              stm(stmNode);
              stmNode = stmNode->getNextSibling();
            }
            interpreter.execPasso(lv, ps);
            ate = expr(ateNode);
            stmNode = first_stm;
          }

          //lv deve ter um valor a mais do que at� (ou a menos, se loop decrescente).
          //setar o valor de lv para valor de ate
          interpreter.execAttribution(lv, ate);
          _t = _retTree;
        }
    )
  ;

passo returns [int p]
{bool pos = true;}
  : #(T_KW_PASSO (T_MAIS|T_MENOS{pos=false;})? i:T_INT_LIT)
      {p = atoi(i->getText().c_str());if(!pos) p = -p;}
  ;

expr returns [ExprValue v]
{ExprValue left, right;}
  : #(T_KW_OU       left=expr right=expr) {v = interpreter.evaluateOu(left, right);}
  | #(T_KW_E        left=expr right=expr) {v = interpreter.evaluateE(left, right);}
  | #(T_BIT_OU      left=expr right=expr) {v = interpreter.evaluateBitOu(left, right);}
  | #(T_BIT_XOU     left=expr right=expr) {v = interpreter.evaluateBitXou(left, right);}
  | #(T_BIT_E       left=expr right=expr) {v = interpreter.evaluateBitE(left, right);}
  | #(T_IGUAL       left=expr right=expr) {v = interpreter.evaluateIgual(left, right);}
  | #(T_DIFERENTE   left=expr right=expr) {v = interpreter.evaluateDif(left, right);}
  | #(T_MAIOR       left=expr right=expr) {v = interpreter.evaluateMaior(left, right);}
  | #(T_MENOR       left=expr right=expr) {v = interpreter.evaluateMenor(left, right);}
  | #(T_MAIOR_EQ    left=expr right=expr) {v = interpreter.evaluateMaiorEq(left, right);}
  | #(T_MENOR_EQ    left=expr right=expr) {v = interpreter.evaluateMenorEq(left, right);}
  | #(T_MAIS        left=expr right=expr) {v = interpreter.evaluateMais(left, right);}
  | #(T_MENOS       left=expr right=expr) {v = interpreter.evaluateMenos(left, right);}
  | #(T_DIV         left=expr right=expr) {v = interpreter.evaluateDiv(left, right);}
  | #(T_MULTIP      left=expr right=expr) {v = interpreter.evaluateMultip(left, right);}
  | #(T_MOD         left=expr right=expr) {v = interpreter.evaluateMod(left, right);}
  | #(TI_UN_NEG     right=element) {v = interpreter.evaluateUnNeg(right);}
  | #(TI_UN_POS     right=element) {v = interpreter.evaluateUnPos(right);}
  | #(TI_UN_NOT     right=element) {v = interpreter.evaluateUnNot(right);}
  | #(TI_UN_BNOT    right=element) {v = interpreter.evaluateUnBNot(right);}
  | v=element          //{v = interpreter.evaluateElement(v);}
  ;


element returns [ExprValue v]
{LValue l;}
  : v=literal
  | v=fcall
  | l=lvalue {v=interpreter.getLValueValue(l);}
  | #(TI_PARENTHESIS v=expr)
  ;

literal returns [ExprValue v]
  : l:T_STRING_LIT     {v.setValue(parseLiteral(l->getText()));v.type = TIPO_LITERAL;}
  | i:T_INT_LIT        {v.setValue(i->getText());v.type = TIPO_INTEIRO;}
  | r:T_REAL_LIT       {v.setValue(r->getText());v.type = TIPO_REAL;}
  | c:T_CARAC_LIT      {v.setValue(parseChar(c->getText()));v.type = TIPO_CARACTERE;}
  | lv:T_KW_VERDADEIRO {v.setValue("1");v.type = TIPO_LOGICO;}
  | lf:T_KW_FALSO      {v.setValue("0");v.type = TIPO_LOGICO;}
  ;

func_decls[list<ExprValue>& args, int line]
  : #(id:T_IDENTIFICADOR
      {
        interpreter.beginFunctionCall(id->getFilename(), id->getText(), args, line);

        while(_t->getType() != T_KW_INICIO) {
          _t = _t->getNextSibling();
        }
      }
      inicio

      {
        interpreter.endFunctionCall();
      }
    )
  ;

