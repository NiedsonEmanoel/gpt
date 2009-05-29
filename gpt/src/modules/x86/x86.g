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
  #include "X86.hpp"
  #include <string>
  #include <sstream>

  using namespace std;
}

options {
  language="Cpp";
}

class X86Walker extends TreeParser;
options {
  importVocab=Portugol;  // use vocab generated by lexer
  ASTLabelType="RefPortugolAST";
  noConstructors=true;
  genHashLines=false;//no #line
}

{
  public:
  X86Walker(SymbolTable& st)
    : stable(st), x86(st) {}

  private:
    SymbolTable& stable;
    X86 x86;

    int calcMatrixOffset(int c, list<int>& dims) {
      int res = 1;
      list<int>::reverse_iterator it = dims.rbegin();
      while(--c) {
        res *= (*it);
        it++;
      }
      return res;
    }
}

/********************************* Producoes **************************************/

algoritmo returns [string str]
  : #(T_KW_ALGORITMO id:T_IDENTIFICADOR) {x86.init(id->getText());}
    (variaveis[X86::VAR_GLOBAL])? 
     principal
    (func_decls)*

  {
    str = x86.source();
  }
  ;

variaveis[int decl_type]
  : #(T_KW_VARIAVEIS (primitivo[decl_type] | matriz[decl_type])+ )
  ;

primitivo[int decl_type]
{
  int type;
  stringstream str;
}
  : #(TI_VAR_PRIMITIVE type=tipo_prim
      (
        id:T_IDENTIFICADOR
        {x86.declarePrimitive(decl_type, id->getText(), type);}
      )+
    )
  ;

tipo_prim returns [int t]
  : T_KW_INTEIRO   {t = TIPO_INTEIRO;}
  | T_KW_REAL      {t = TIPO_REAL;}
  | T_KW_CARACTERE {t = TIPO_CARACTERE;}
  | T_KW_LITERAL   {t = TIPO_LITERAL;}
  | T_KW_LOGICO    {t = TIPO_LOGICO;}
  ;

matriz[int decl_type]
{
  pair<int, list<string> > tp;
}
  : #(TI_VAR_MATRIX tp=tipo_matriz 
      (
        id:T_IDENTIFICADOR
        {x86.declareMatrix(decl_type, tp.first, id->getText(), tp.second);}
      )+
    )
  ;


tipo_matriz returns [pair<int, list<string> > p] //pair<type, list<dimsize> >
  : #(T_KW_INTEIROS 
      {p.first = TIPO_INTEIRO;}
      (
        s1:T_INT_LIT
        {p.second.push_back(s1->getText());}
      )+
    )
  | #(T_KW_REAIS
      {p.first = TIPO_REAL;}
      (
        s2:T_INT_LIT
        {p.second.push_back(s2->getText());}
      )+
    )
  | #(T_KW_CARACTERES
      {p.first = TIPO_CARACTERE;}
      (
        s3:T_INT_LIT
        {p.second.push_back(s3->getText());}
      )+
    )
  | #(T_KW_LITERAIS
      {p.first = TIPO_LITERAL;}
      (
        s4:T_INT_LIT
        {p.second.push_back(s4->getText());}
      )+
    )
  | #(T_KW_LOGICOS
      {p.first = TIPO_LOGICO;}
      (
        s5:T_INT_LIT
        {p.second.push_back(s5->getText());}
      )+
    )
  ;

principal
  : stm_block
    {
            x86.writeTEXT("mov ecx, 0");
            x86.writeExit();
    }
  ;

stm_block
  : #(T_KW_INICIO (stm)* )
  ;

stm
  : stm_attr
  | fcall[TIPO_ALL] {x86.writeTEXT("pop eax");}
  | stm_ret
  | stm_se
  | stm_enquanto
  | stm_para
  ;

stm_attr
{
  stringstream s;
  pair<pair<int, bool>, string> lv;
  int expecting_type;
  int etype;
  Symbol symb;
}
  : #(T_ATTR lv=lvalue
      {
        symb = stable.getSymbol(x86.currentScope(), lv.second, true);
        expecting_type = symb.type.primitiveType();
        x86.writeTEXT("push ecx");
      }

      etype=expr[expecting_type]
		)

    {
      x86.writeAttribution(etype, expecting_type, lv);
    }
  ;

lvalue returns [pair< pair<int, bool>, string> p] //pair< pair<type, using_addr>, name>
{
  stringstream s;
  list<int> dims;
  Symbol symb;
  bool isprim;
  int multiplier;
  int c;  
}
  : #(id:T_IDENTIFICADOR
      {
        symb = stable.getSymbol(x86.currentScope(), id->getText(), true);
        p.first.first = symb.type.primitiveType();
        isprim = symb.type.isPrimitive();
        p.second = id->getText();

        dims = symb.type.dimensions();
        c = dims.size();

       if(!isprim) {
          p.first.second = true;
          x86.writeTEXT("push 0");
        } else {
          p.first.second = false;
        }
      }

      (
        expr[TIPO_INTEIRO] //index expr type

        {
          p.first.second = false;
          multiplier = calcMatrixOffset(c, dims);
          x86.writeTEXT("pop eax");

          s << "mov ebx, " << multiplier;
          x86.writeTEXT(s.str());
          x86.writeTEXT("imul ebx");
          x86.writeTEXT("pop ebx");
          x86.writeTEXT("add eax, ebx");
          x86.writeTEXT("push eax");
          s.str("");
          c--;
        }
      )*
    )

    {
      if(symb.type.isPrimitive()) {        
        x86.writeTEXT("mov ecx, 0");
      } else {
        x86.writeTEXT("pop ecx");
      }
    }
  ;

fcall[int expct_type] returns [int type]
{
  Symbol f;
  int count = 0;

  stringstream s;
  string fname, fimp;
  int args = 0;
  int etype;
  int ptype = 0;

  list<int> imp_ptypes;
}
  : #(TI_FCALL id:T_IDENTIFICADOR 
      {
        f = stable.getSymbol(SymbolTable::GlobalScope, id->getText()); //so we get the params                
        if(f.lexeme == "leia") {
          fname = x86.translateFuncLeia(id->getText(), expct_type);
          type = expct_type;
          //ptype doesn't matter: (expr)* is not used
        } else {
          fname = f.lexeme;
          type = f.type.primitiveType();
        }
        ptype = f.param.paramType(count++);
      }
      (
        etype=expr[ptype]
        {
          if(fname == "imprima") {
            //imp_ptypes.push_back(etype);
            switch(etype) {
              case TIPO_INTEIRO:
                x86.writeTEXT("addarg 'i'");
                break;
              case TIPO_REAL:
                x86.writeTEXT("addarg 'r'");
                break;
              case TIPO_CARACTERE:
                x86.writeTEXT("addarg 'c'");
                break;
              case TIPO_LITERAL:
                x86.writeTEXT("addarg 's'");
                break;
              case TIPO_LOGICO:
                x86.writeTEXT("addarg 'l'");
                break;
            }
          } else {            
            x86.writeTEXT("pop eax");
            x86.writeCast(etype, ptype);
            x86.writeTEXT("addarg eax");
            ptype = f.param.paramType(count++);
          }
          args++;
        }
      )*
    )
    {      
      if(fname == "imprima") {
        s << "addarg " << args;
        x86.writeTEXT(s.str());
        x86.writeTEXT("call imprima");
        s.str("");
        s << "clargs " << ((args*2)+1);
        x86.writeTEXT(s.str());      
        x86.writeTEXT("print_lf"); //\n
      } else if(f.lexeme == "leia"){
        x86.writeTEXT(string("call ") + fname);
/*        if(args) {
          s << "clargs " << args;
          x86.writeTEXT(s.str());*/
      } else {
        x86.writeTEXT(string("call ") + X86::makeID(fname));
        if(args) {
          s << "clargs " << args;
          x86.writeTEXT(s.str());
        }
      }

      x86.writeTEXT("push eax");
    }
  ;


stm_ret
{
  int expecting_type=TIPO_NULO;
  int etype;
  bool isGlobalEscope = (x86.currentScope()==SymbolTable::GlobalScope);
  if (isGlobalEscope){
    expecting_type = TIPO_INTEIRO; // o retorno no bloco principal é do TIPO_INTEIRO
  }else{
    expecting_type = stable.getSymbol(SymbolTable::GlobalScope, x86.currentScope(), true).type.primitiveType();
  }  
}
  : #(T_KW_RETORNE (TI_NULL|etype=expr[expecting_type]))
    {
      if (isGlobalEscope){
        x86.writeTEXT("pop ecx");
        x86.writeExit();
      } else {
      	if(expecting_type != TIPO_NULO) {
        	x86.writeTEXT("pop eax");
      	}
      	if(expecting_type == TIPO_LITERAL) {
        	x86.writeTEXT("addarg eax");
        	x86.writeTEXT("call clone_literal");
        	x86.writeTEXT("clargs 1");
      	} else {
        	x86.writeCast(etype, expecting_type);
      	}
      
      	x86.writeTEXT("return");
      }
    }
  ;

stm_se
{
  stringstream s;
  string lbnext, lbfim;

  lbnext = x86.createLabel(true, "next_se");
  lbfim  = x86.createLabel(true, "fim_se");

  bool hasElse = false;
  
  x86.writeTEXT("; se: expressao");
}
  : #(T_KW_SE expr[TIPO_LOGICO]

    {      
      x86.writeTEXT("; se: resultado");
      x86.writeTEXT("pop eax");
      x86.writeTEXT("cmp eax, 0");
      s << "je near " << lbnext;
      x86.writeTEXT(s.str());

      x86.writeTEXT("; se: verdadeiro:");
    }

      (stm)*
    (
        T_KW_SENAO

      {
        hasElse = true;

        s.str("");
        s << "jmp " << lbfim;
        x86.writeTEXT(s.str());

        x86.writeTEXT("; se: falso:");

        s.str("");
        s << lbnext << ":";
        x86.writeTEXT(s.str());
      }
        (stm)*
      )?
    )

    {
      x86.writeTEXT("; se: fim:");

      s.str("");
      if(hasElse) {
        s << lbfim << ":";        
      } else {
        s << lbnext << ":";
      }
      x86.writeTEXT(s.str());
    }
  ;

stm_enquanto
{
  stringstream s;
  string lbenq = x86.createLabel(true, "enquanto");;
  string lbfim = x86.createLabel(true, "fim_enquanto");;

  s << lbenq << ":";
  x86.writeTEXT(s.str());
  s.str("");

  x86.writeTEXT("; while: expressao");
}
  : #(T_KW_ENQUANTO expr[TIPO_LOGICO]
      {
        x86.writeTEXT("; while: resultado");
        x86.writeTEXT("pop eax");
        x86.writeTEXT("cmp eax, 0");
        s << "je near " << lbfim;
        x86.writeTEXT(s.str());
      }
      (stm)*

      {
        s.str("");
        s << "jmp " << lbenq;
        x86.writeTEXT(s.str());

        s.str("");
        s << lbfim << ":";
        x86.writeTEXT(s.str());
      }
    )
  ;

stm_para
{
  stringstream s;
  pair< pair<int, bool>, string> lv;
  pair<int, string> ps;
  int de_type, ate_type;
  bool hasPasso = false;
  string lbpara = x86.createLabel(true, "para");
  string lbfim  = x86.createLabel(true, "fim_para");

  x86.writeTEXT("; para: lvalue:");
}
  : #(T_KW_PARA 

        lv=lvalue
        {
          Symbol symb = stable.getSymbol(x86.currentScope(), lv.second, true);
          int expecting_type = symb.type.primitiveType();
          x86.writeTEXT("push ecx"); //lvalue's offset to be used later
          x86.writeTEXT("; para: de:");
        }

        de_type=expr[TIPO_INTEIRO] 

        {
          x86.writeTEXT("; para: de attr:");
          x86.writeAttribution(de_type, expecting_type, lv);
          x86.writeTEXT("push ecx");
          x86.writeTEXT("; para: ate:");
        }

      ate_type=expr[TIPO_INTEIRO]

        {
          x86.writeTEXT("pop eax");
          x86.writeCast(ate_type, lv.first.first);          
          x86.writeTEXT("push eax");//top stack tem "ate"

        }

      (
        ps=passo {hasPasso=true;}
      )?

        {
          //nao entrar se condicao falsa
          x86.writeTEXT("mov ecx, dword [esp+4]");
          s.str("");
          s << "lea edx, [" << X86::makeID(lv.second) << "]";
          x86.writeTEXT(s.str());
          x86.writeTEXT("mov eax, dword [edx + ecx * SIZEOF_DWORD]");

          x86.writeTEXT("mov ebx, dword [esp]");
          x86.writeTEXT("cmp eax, ebx");

          s.str("");
          if(hasPasso && ps.first) {
            s << "jl " << lbfim;
          } else {
            s << "jg near " << lbfim;
          }
          x86.writeTEXT(s.str());

          s.str("");
          s << lbpara << ":";
          x86.writeTEXT(s.str());          
        }

      (stm)*

        {
          //calcular passo [eax]          
          x86.writeTEXT("mov ecx, dword [esp+4]");
          s.str("");
          s << "lea edx, [" << X86::makeID(lv.second) << "]";
          x86.writeTEXT(s.str());
          x86.writeTEXT("mov eax, dword [edx + ecx * SIZEOF_DWORD]");

          s.str("");
          if(!hasPasso) {
            x86.writeTEXT("inc eax");
          } else {
            if(ps.first) { //dec
              s << "sub eax, " << ps.second;
            } else { //cresc
              s << "add eax, " << ps.second;
            }
          }
          x86.writeTEXT(s.str());
          
          //desviar constrole          
          x86.writeTEXT("mov ebx, dword [esp]");
          x86.writeTEXT("cmp eax, ebx");

          s.str("");
          if(hasPasso && ps.first) {
            s << "jl near " << lbfim;
          } else {
            s << "jg near " << lbfim;
          }
          x86.writeTEXT(s.str());

          s.str("");
          s << "lea edx, [" << X86::makeID(lv.second) << "]";
          x86.writeTEXT(s.str());
          x86.writeTEXT("mov ecx, dword [esp+4]");          
          x86.writeTEXT("lea edx, [edx + ecx * SIZEOF_DWORD]");
          x86.writeTEXT("mov dword [edx], eax");

          s.str("");
          s << "jmp " << lbpara;
          x86.writeTEXT(s.str());

          s.str("");
          s << lbfim << ":";
          x86.writeTEXT(s.str());

          //lvalue = ate value
          x86.writeTEXT("mov ebx, dword [esp]");
          s.str("");
          s << "lea edx, [" << X86::makeID(lv.second) << "]";
          x86.writeTEXT(s.str());
          x86.writeTEXT("mov ecx, dword [esp+4]");          
          x86.writeTEXT("lea edx, [edx + ecx * SIZEOF_DWORD]");
          x86.writeTEXT("mov dword [edx], ebx");

          //pop ate, pop lvalue offset
          x86.writeTEXT("pop eax");
          x86.writeTEXT("pop ecx");
          x86.writeTEXT("; fimpara");
        }
    )
  ;

passo returns [pair<int, string> p]
  : #(T_KW_PASSO (
          T_MAIS   {p.first = 0;}
        | T_MENOS  {p.first = 1;}
        )? 
      i:T_INT_LIT {p.second = i->getText();}
    )
  ;

expr[int expecting_type] returns [int etype]
{
  int e1, e2;
  stringstream s;
  etype = #expr->getEvalType();
}
  : #(T_KW_OU     e1=expr[expecting_type] e2=expr[expecting_type]) 
      {
        x86.writeOuExpr();
      }
  | #(T_KW_E      e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeEExpr();
      }
  | #(T_BIT_OU    e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeBitOuExpr();
      }
  | #(T_BIT_XOU   e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeBitXouExpr();
      }
  | #(T_BIT_E     e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeBitEExpr();
      }
  | #(T_IGUAL     e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeIgualExpr(e1, e2);
      }
  | #(T_DIFERENTE e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeDiferenteExpr(e1, e2);
      }
  | #(T_MAIOR     e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeMaiorExpr(e1, e2);
      }
  | #(T_MENOR     e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeMenorExpr(e1, e2);
      }
  | #(T_MAIOR_EQ  e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeMaiorEqExpr(e1, e2);
      }
  | #(T_MENOR_EQ  e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeMenorEqExpr(e1, e2);
      }

  | #(T_MAIS  e1=expr[expecting_type] e2=expr[expecting_type]) 
      {
        x86.writeMaisExpr(e1,e2);
      }
  | #(T_MENOS     e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeMenosExpr(e1, e2);
      }
  | #(T_DIV       e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeDivExpr(e1, e2);
      }
  | #(T_MULTIP    e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeMultipExpr(e1, e2);
      }
  | #(T_MOD       e1=expr[expecting_type] e2=expr[expecting_type])
      {
        x86.writeModExpr();
      }
  | #(TI_UN_NEG   etype=element[expecting_type])
      {
        x86.writeUnaryNeg(etype);
      }
  | #(TI_UN_POS   etype=element[expecting_type])
      {
        //nothing
      }
  | #(TI_UN_NOT   etype=element[expecting_type])
      {
        x86.writeUnaryNot();
      }
  | #(TI_UN_BNOT  etype=element[expecting_type])
      {
        x86.writeUnaryBitNotExpr();
      }
  | etype=element[expecting_type]
  ;

element[int expecting_type] returns [int etype]
{
  stringstream s;
  string str;
  pair<int, string> lit;
  pair< pair<int, bool>, string> lv;
}
  : lit=literal {x86.writeLiteralExpr(lit.second);etype = lit.first;}
  | etype=fcall[expecting_type]
  | lv=lvalue  {x86.writeLValueExpr(lv);etype = lv.first.first;}
  | #(TI_PARENTHESIS etype=expr[expecting_type])
  ;

literal returns [pair<int, string> p]
  : s:T_STRING_LIT        
    {
      if(s->getText().length() > 0) {
        p.second = x86.addGlobalLiteral(s->getText());
      } else {
        p.second = "0";
      }
      p.first = TIPO_LITERAL;
    }
  | i:T_INT_LIT           {p.second = i->getText();p.first = TIPO_INTEIRO;}
  | c:T_CARAC_LIT         {p.second = x86.toChar(c->getText());p.first = TIPO_CARACTERE;}
  | v:T_KW_VERDADEIRO     {p.second = "1";p.first = TIPO_LOGICO;}
  | f:T_KW_FALSO          {p.second = "0";p.first = TIPO_LOGICO;}
  | r:T_REAL_LIT          {p.second = x86.toReal(r->getText());p.first = TIPO_REAL;}
  ;

func_decls
  : #(id:T_IDENTIFICADOR   
      {
        x86.createScope(id->getText());
      }

      (primitivo[X86::VAR_PARAM] | matriz[X86::VAR_PARAM])*

      //(ret_type)?

      {
        if((_t != antlr::nullAST) && (_t->getType() == TI_FRETURN)) {
          _t = _t->getNextSibling();
        }
      }

      (variaveis[X86::VAR_LOCAL])?
      stm_block
      {
        x86.writeTEXT("return");
      }
    )
  ;
