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
  xmlns:func = "http://exslt.org/functions"
  xmlns:str="http://exslt.org/strings"
  extension-element-prefixes="exsl func str">

  <xsl:import href="utils.xsl" />

  <xsl:output
    method="xml"
    encoding="utf-8" />

  <xsl:variable name="bml-element">
    <xsl:element name="bml:element" />
  </xsl:variable>

  <!-- make a copy of the XML file with selected alterations -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/*[b:auto-svg()]">
    <xsl:copy>
      <xsl:copy-of select="exsl:node-set($bml-element)/*/namespace::*" />
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <!-- replace PDF, EPS images with auto-generated SVGs if no other candidates are available -->
  <xsl:template match="ltx:graphics[b:auto-svg-source() != '']/@graphic">
    <xsl:attribute name="graphic">
      <xsl:value-of select="b:auto-svg-candidate()" />
    </xsl:attribute>
    <xsl:if test="not(../@candidates)">
      <xsl:attribute name="candidates">
        <xsl:value-of select="b:auto-svg-candidate()" />
      </xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:graphics/@candidates[b:auto-svg-source() != '']">
    <xsl:attribute name="candidates">
      <xsl:value-of select="b:auto-svg-candidate()" />
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="ltx:graphics[b:auto-svg-source() != '' and b:page-option() != '']/@options">
    <xsl:variable name="split-options" select="str:split(b:escape-options(self::ltx:graphics/@options | ../@options),',')" />
    <xsl:attribute name="options">
      <xsl:for-each select="$split-options/text()[not(starts-with(.,'page='))]" >
        <xsl:value-of select="b:unescape-option(.)" />
        <xsl:text>,</xsl:text>
      </xsl:for-each>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="ltx:graphics[b:auto-svg-source() != '' and (b:auto-svg-parent() != '' or @options[b:page-option() != ''])]">
    <xsl:copy>
      <xsl:attribute name="bml:source"><xsl:value-of select="b:auto-svg-source()" /></xsl:attribute>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <!-- auto EPS/PDF to SVG conversion -->
  <func:function name="b:escape-options">
    <xsl:param name="options"/>
    <func:result select="str:replace(str:replace($options,'%','%25'),'\,','%2C')"/>
  </func:function>

  <func:function name="b:unescape-option">
    <xsl:param name="escaped-option" />
    <func:result select="str:replace(str:replace($escaped-option,'%2C',','),'%25','%')" />
  </func:function>

  <func:function name="b:page-option">
    <xsl:param name="split-options" select="str:split(b:escape-options(self::ltx:graphics/@options | ../@options),',')" />
    <func:result select="substring-after(($split-options/text()[starts-with(.,'page=')])[last()],'page=')" />
  </func:function>

  <func:function name="b:if">
    <xsl:param name="test" />
    <xsl:param name="yes" />
    <xsl:param name="no" />
    <xsl:choose>
      <xsl:when test="$test"><func:result select="$yes" /></xsl:when>
      <xsl:otherwise><func:result select="$no" /></xsl:otherwise>
    </xsl:choose>
  </func:function>

  <func:function name="b:auto-svg-source">
    <xsl:param name="candidates" select="str:split(str:replace(b:if(self::ltx:graphics,b:if(@candidates,@candidates,@graphic),b:if(../self::ltx:graphics,b:if(../@candidates,../@candidates,../@graphic))),'\','/'),',')" />
    <func:result>
      <!-- if we only have EPS/PDF candidates, pick the first, preferring EPS -->
      <!-- .tex files are considered candidates (why exactly?) -->
      <xsl:if test="not($candidates//text()[not(b:ends-with(b:lower-case(.),'.eps') or b:ends-with(b:lower-case(.),'.pdf') or b:ends-with(b:lower-case(.),'.tex'))])">
        <xsl:variable name="eps" select="($candidates//text()[b:ends-with(b:lower-case(.),'.eps')])[1]"/>
        <xsl:variable name="pdf" select="($candidates//text()[b:ends-with(b:lower-case(.),'.pdf')])[1]"/>
        <xsl:variable name="tex" select="($candidates//text()[b:ends-with(b:lower-case(.),'.tex')])[1]"/>
        <xsl:choose>
          <xsl:when test="contains($AUTOSVG,'eps') and $eps != ''">
            <xsl:value-of select="$eps" />
          </xsl:when>
          <xsl:when test="contains($AUTOSVG,'pdf') and $pdf != ''">
            <xsl:value-of select="$pdf" />
          </xsl:when>
          <xsl:when test="contains($AUTOSVG,'pdf') and $tex != ''">
            <xsl:value-of select="concat(substring($tex,1,string-length($tex) - 3),'pdf')" />
          </xsl:when>
        </xsl:choose>
      </xsl:if>
      <!-- otherwise, assume that the author is providing their own conversion -->
    </func:result>
  </func:function>

  <func:function name="b:is-within-cwd">
    <xsl:param name="path"/>
    <!-- Win32: also check if path starts with drive letter -->
    <func:result select="not(substring($path,2,1)=':' or starts-with($path,'/') or starts-with($path,'../'))"/>
  </func:function>

  <func:function name="b:auto-svg-without-parent">
    <xsl:param name="source" select="b:auto-svg-source()"/>
    <!-- if $source is not below the current folder, we remove the folder, as latexmlpost would do -->
    <func:result>
      <xsl:choose>
        <xsl:when test="b:is-within-cwd($source)">
          <xsl:value-of select="$source" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="str:split($source,'/')[last()]//text()" />
        </xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>

  <func:function name="b:auto-svg-parent">
    <xsl:param name="source" select="b:auto-svg-source()"/>
    <xsl:param name="source-without-parent" select="b:auto-svg-without-parent($source)" />
    <func:result>
      <xsl:value-of select="substring($source,1,string-length($source) - string-length($source-without-parent))"/>
    </func:result>
  </func:function>

  <func:function name="b:auto-svg-candidate">
    <xsl:param name="source" select="b:auto-svg-source()"/>
    <xsl:param name="page" select="b:page-option()"/>

    <func:result>
      <xsl:if test="$source != ''">
        <!-- if $source is not below the current folder, we remove the folder, as latexmlpost would do -->
        <xsl:variable name="source-without-parent" select="b:auto-svg-without-parent($source)" />

        <xsl:text>bmlimages/svg/</xsl:text>
        <xsl:choose>
          <xsl:when test="$page != ''">
            <xsl:value-of select="$source-without-parent" />
            <xsl:text>/p</xsl:text>
            <xsl:value-of select="$page" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="substring($source-without-parent,1,string-length($source-without-parent)-4)" />
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text>.svg</xsl:text>
      </xsl:if>
    </func:result>
  </func:function>

</xsl:stylesheet>
