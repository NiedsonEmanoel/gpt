#include <Tools.hpp>

#include "CTemporarySymbol.hpp"

CTemporarySymbol::CTemporarySymbol( )
	: _baseName("_ts"), _count(1)
{
}

CTemporarySymbol::CTemporarySymbol( const string &baseName, const int &initialValue)
	: _baseName(baseName), _count(initialValue)
{
}

CTemporarySymbol::~CTemporarySymbol( )
{
}

void CTemporarySymbol::setBaseName( string baseName )
{
	_baseName = baseName;
}

void CTemporarySymbol::setInitialValue( int initialValue )
{
	_count = initialValue;
}

string CTemporarySymbol::getNew( )
{
	return( _baseName + itoa( _count++ ) );
}

void CTemporarySymbol::removeLast( )
{
	_count--;
}

unsigned int CTemporarySymbol::getMaxUsed( )
{
	return( _count );
}

string CTemporarySymbol::getLast( )
{
	return( _baseName + itoa( _count - 1 ) );
}
