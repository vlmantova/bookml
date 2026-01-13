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
      <xsl:value-of select="$BML_TARGET" /><xsl:text>: LATEXMLPOSTAUTOFLAGS=--navigationtoc=context&#x0A;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="//ltx:resource | //ltx:graphics/@candidates" />
  </xsl:template>

  <xsl:template match="ltx:resource">
    <xsl:value-of select="$BML_TARGET" /><xsl:text>: </xsl:text><xsl:value-of select="@src" /><xsl:text>&#x0A;</xsl:text>
    <xsl:value-of select="@src" /><xsl:text>:&#x0A;</xsl:text>
  </xsl:template>

  <!-- convert PDF and EPS to SVG using dvisvgm (instead of letting LaTeXML rely on ImageMagick) -->
  <xsl:template match="ltx:graphics/@candidates">
    <xsl:variable name="candidates" select="str:split(str:replace(.,'\','/'),',')" />
    <xsl:variable name="source" select="b:auto-svg-source($candidates)" />

    <xsl:choose>
      <xsl:when test="$source = ''">
        <!-- add dependency on existing candidates -->
        <xsl:for-each select="$candidates">
          <xsl:value-of select="$BML_TARGET" />
          <xsl:text>: </xsl:text>
          <xsl:value-of select="string()" />
          <xsl:text>&#x0A;</xsl:text>
          <xsl:value-of select="string()" />
          <xsl:text>:&#x0A;</xsl:text>
        </xsl:for-each>
      </xsl:when>

      <xsl:otherwise>
        <xsl:variable name="page" select="b:page-option()" />
        <xsl:variable name="candidate" select="b:auto-svg-candidate($source,$page)" />

        <!-- add dependency on new candidate -->
        <xsl:value-of select="$BML_TARGET" />
        <xsl:text>: </xsl:text>
        <xsl:value-of select="$candidate" />
        <xsl:text>&#x0A;</xsl:text>

        <!-- do not try to build source -->
        <xsl:value-of select="$source" />
        <xsl:text>:&#x0A;</xsl:text>

        <xsl:variable name="source-without-parent">
          <xsl:choose>
            <xsl:when test="b:is-within-cwd($source)">
              <xsl:value-of select="$source" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="str:split($source,'/')[last()]" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>

        <xsl:variable name="parent">
          <xsl:if test="$source-without-parent != $source">
            <xsl:value-of select="substring($source,1,string-length($source) - string-length($source-without-parent))"/>
          </xsl:if>
        </xsl:variable>

        <xsl:if test="$parent != ''">
          <xsl:value-of select="$candidate" />
          <xsl:text>: bml.svg.parent=</xsl:text>
          <xsl:value-of select="$parent" />
          <xsl:text>&#x0A;</xsl:text>
        </xsl:if>

        <xsl:if test="$page != ''">
          <!-- add manual rules that are not caught by the make pattern rule -->
          <xsl:variable name="ext" select="b:lower-case(substring($source,string-length($source)-2))" />

          <xsl:value-of select="$candidate" />
          <xsl:text>: bml.svg.page=</xsl:text>
          <xsl:value-of select="$page" />
          <xsl:text>&#x0A;</xsl:text>

          <xsl:value-of select="$candidate" />
          <xsl:text>: </xsl:text>
          <xsl:value-of select="$source" />
          <xsl:text> $(BOOKML_DEPS_AUTOSVG) | bmlimages/svg</xsl:text>
          <xsl:text>/</xsl:text>
          <xsl:value-of select="$source-without-parent" />
          <xsl:text>/./&#x0A;</xsl:text>
          <!-- WARNING: must be kept in sync with bookml.mk -->
          <xsl:text>&#x09;@$(bml.pdftosvg)&#x0A;</xsl:text>
          <xsl:text>&#x09;@$(bml.pdftosvg.proc)&#x0A;</xsl:text>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
