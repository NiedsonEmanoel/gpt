INCLUDES = -I$(top_srcdir)/. -I$(top_srcdir)/src/parser \
	-I$(top_srcdir)/src/modules -I$(top_srcdir)/src/modules/parser \
	$(ANTLR_INC) $(all_includes)

noinst_LTLIBRARIES = libparser.la

BUILT_SOURCES = PortugolLexer.cpp  PortugolParser.cpp SemanticWalker.cpp 

nodist_libparser_la_SOURCES = $(BUILT_SOURCES)

headers = BasePortugolParser.hpp SemanticEval.hpp MismatchedUnicodeCharException.hpp \
          UnicodeCharBuffer.hpp UnicodeCharScanner.hpp

libparser_la_SOURCES = BasePortugolParser.cpp SemanticEval.cpp MismatchedUnicodeCharException.cpp

if INSTALL_DEVEL
nodist_pkginclude_HEADERS = PortugolParserTokenTypes.hpp PortugolLexer.hpp \
                            PortugolParser.hpp PortugolTokenTypes.hpp \
								            SemanticWalker.hpp SemanticWalkerTokenTypes.hpp

pkginclude_HEADERS = $(headers)
else
noinst_HEADERS = $(headers)
endif

lexer_g       = lexer.g
parser_g      = parser.g
semantic_g    = semantic.g

EXTRA_DIST = $(lexer_g) $(parser_g) $(semantic_g) accent.sh

CLEANFILES = PortugolLexer.cpp PortugolLexer.hpp PortugolParser.cpp PortugolParser.hpp \
             PortugolParserTokenTypes.hpp PortugolParserTokenTypes.txt \
             PortugolTokenTypes.hpp PortugolTokenTypes.txt SemanticWalker.hpp \
             SemanticWalker.cpp SemanticWalkerTokenTypes.hpp SemanticWalkerTokenTypes.txt

PortugolLexer.cpp: $(srcdir)/$(lexer_g)
	$(ANTLR_BIN) $(srcdir)/$(lexer_g)
	cp PortugolTokenTypes.txt ../c_translator
	cp PortugolTokenTypes.txt ../interpreter
	cp PortugolTokenTypes.txt ../x86	

PortugolParser.cpp: $(srcdir)/$(parser_g) PortugolLexer.cpp
	$(ANTLR_BIN) $(srcdir)/$(parser_g)
	./$(srcdir)/accent.sh

SemanticWalker.cpp: $(srcdir)/$(semantic_g) PortugolLexer.cpp
	$(ANTLR_BIN) $(srcdir)/$(semantic_g)
