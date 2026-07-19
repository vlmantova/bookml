<?xml version="1.0" encoding="utf-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-25 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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
  xmlns:b="https://vlmantova.github.io/bookml/functions"
  xmlns:exsl="http://exslt.org/common"
  xmlns:str="http://exslt.org/strings"
  extension-element-prefixes="exsl str">

  <xsl:import href="utils.xsl"/>

  <xsl:output
    method="text"
    encoding="utf-8" />

  <xsl:param name="BML_TARGET" />

  <xsl:template match="/">
    <xsl:if test="$BMLSTYLE='gitbook'">
      <xsl:text>$(AUX_DIR)/</xsl:text>
      <xsl:value-of select="$BML_TARGET" />
      <xsl:text>: LATEXMLPOSTAUTOFLAGS=--navigationtoc=context&#x0A;</xsl:text>
    </xsl:if>
    <xsl:text>$(AUX_DIR)/</xsl:text><xsl:value-of select="$BML_TARGET" /><xsl:text>:</xsl:text>
    <xsl:for-each select="//ltx:resource/@src | //ltx:graphics/@candidates">
      <xsl:text> \&#x0A;  </xsl:text>
      <xsl:value-of select="." />
    </xsl:for-each>
    <xsl:text>&#x0A;&#x0A;</xsl:text>
    <xsl:variable name="pdfs">
      <xsl:for-each select="//ltx:resource/@src | //ltx:graphics/@candidates">
        <xsl:if test="translate(substring(.,string-length(.) - 3),'PDF','pdf') = '.pdf' and not(starts-with(.,'/')) and not(starts-with(.,'../')) and not(substring(.,2,1) = ':')">
          <xsl:text> $(AUX_DIR)/pdf/</xsl:text>
          <xsl:value-of select="." />
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:if test="$pdfs != ''">
      <xsl:text>ifneq (,$(filter $(AUX_DIR)/</xsl:text>
      <xsl:value-of select="$BML_TARGET" />
      <xsl:text>,$(BMLGOALS.HTML)))&#x0A;</xsl:text>
      <xsl:text>BMLGOALS.PDF +=</xsl:text>
      <xsl:value-of select="$pdfs" />
      <xsl:text>&#x0A;endif&#x0A;&#x0A;</xsl:text>
    </xsl:if>
    <xsl:for-each select="//ltx:resource/@src | //ltx:graphics/@candidates">
      <xsl:apply-templates select="." />
      <xsl:text>:&#x0A;</xsl:text>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
