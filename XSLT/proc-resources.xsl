<?xml version="1.0" encoding="utf-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-23 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:ltx="http://dlmf.nist.gov/LaTeXML"
  exclude-result-prefixes="ltx">

  <xsl:import href="utils.xsl"/>

  <xsl:output
    method="text"
    encoding="utf-8" />

  <xsl:param name="BML_TARGET" />

  <xsl:template match="/">
    <xsl:if test="$BMLSTYLE='gitbook'">
      <xsl:value-of select="$BML_TARGET" /><xsl:text>: LATEXMLPOSTAUTOFLAGS=--navigationtoc=context&#x0A;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="//ltx:resource" />
  </xsl:template>

  <xsl:template match="ltx:resource">
    <xsl:value-of select="$BML_TARGET" /><xsl:text>: </xsl:text><xsl:value-of select="@src" /><xsl:text>&#x0A;</xsl:text>
    <xsl:value-of select="@src" /><xsl:text>:&#x0A;</xsl:text>
  </xsl:template>

</xsl:stylesheet>
