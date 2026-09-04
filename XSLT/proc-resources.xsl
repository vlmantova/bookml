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
  xmlns:bml="https://vlmantova.github.io/bookml"
  xmlns:exsl="http://exslt.org/common"
  xmlns:str="http://exslt.org/strings"
  extension-element-prefixes="exsl str">

  <xsl:import href="utils.xsl"/>

  <xsl:output
    method="text"
    encoding="utf-8" />

  <xsl:param name="BML_JOB" />

  <xsl:variable name="TARGET">$(AUX_DIR)/html/<xsl:value-of select="$BML_JOB" />/index.html</xsl:variable>

  <xsl:template match="/">
    <xsl:if test="$BMLSTYLE='gitbook'">
      <xsl:value-of select="$TARGET" />
      <xsl:text>: LATEXMLPOSTAUTOFLAGS=--navigationtoc=context&#x0A;</xsl:text>
    </xsl:if>

    <xsl:value-of select="$TARGET" /><xsl:text>:</xsl:text>

    <xsl:for-each select="//ltx:resource/@src">
      <xsl:text> \&#x0A;  </xsl:text>
      <xsl:value-of select="str:replace(.,' ','\ ')" />
    </xsl:for-each>

    <xsl:for-each select="//ltx:graphics/@candidates">
      <xsl:for-each select="str:split(.,',')">
        <xsl:text> \&#x0A;  </xsl:text>
        <xsl:value-of select="str:replace(.,' ','\ ')" />
      </xsl:for-each>
    </xsl:for-each>

    <xsl:text>&#x0A;&#x0A;</xsl:text>

    <xsl:for-each select="//ltx:resource/@src">
      <xsl:value-of select="str:replace(.,' ','\ ')" />
      <xsl:text>:&#x0A;</xsl:text>
    </xsl:for-each>

    <xsl:for-each select="//ltx:graphics/@candidates">
      <xsl:for-each select="str:split(.,',')">
        <xsl:value-of select="str:replace(.,' ','\ ')" />
        <xsl:text>:&#x0A;</xsl:text>
      </xsl:for-each>
    </xsl:for-each>

    <xsl:if test="//ltx:graphics[@bml:source]">
      <xsl:text>&#x0A;</xsl:text>

      <xsl:for-each select="//ltx:graphics[@bml:source]">
        <xsl:value-of select="@candidates" />
        <xsl:text>: </xsl:text>
        <xsl:value-of select="@bml:source" />
        <xsl:text>&#x0A;</xsl:text>
      </xsl:for-each>
    </xsl:if>

    <xsl:if test="//ltx:graphics[b:ends-with(b:lower-case(@bml:source),'.pdf')]">
      <xsl:text>&#x0A;</xsl:text>

      <xsl:text>bml.autosvg.pdf +=</xsl:text>
      <xsl:for-each select="//ltx:graphics[b:ends-with(b:lower-case(@bml:source),'.pdf')]">
        <xsl:text> </xsl:text>
        <xsl:value-of select="@candidates" />
      </xsl:for-each>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>

    <xsl:if test="//ltx:graphics[b:ends-with(b:lower-case(@bml:source),'.eps')]">
      <xsl:text>&#x0A;</xsl:text>

      <xsl:text>bml.autosvg.eps +=</xsl:text>
      <xsl:for-each select="//ltx:graphics[b:ends-with(b:lower-case(@bml:source),'.eps')]">
        <xsl:text> </xsl:text>
        <xsl:value-of select="@candidates" />
      </xsl:for-each>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>