<?xml version="1.0" encoding="UTF-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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
<xsl:stylesheet
    version    = "1.0"
    xmlns:xsl  = "http://www.w3.org/1999/XSL/Transform"
    xmlns:f    = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:func = "http://exslt.org/functions"
    xmlns:b    = "https://vlmantova.github.io/bookml/functions"
    extension-element-prefixes = "func"
    exclude-result-prefixes    = "f func b">

  <!-- check if $elem is in the $sep-separated $list -->
  <func:function name="b:in-list">
    <xsl:param name="list"/>
    <xsl:param name="elem"/>
    <xsl:param name="sep"/>
    <func:result select=
      "$list and contains(concat($sep,$list,$sep),concat($sep,$elem,$sep))"/>
  </func:function>

  <func:function name="b:has-class">
    <xsl:param name="class"/>
    <xsl:param name="node" select="."/>
    <func:result select="b:in-list($node/@class,$class,' ')"/>
  </func:function>

  <func:function name="b:url-without-fragment">
    <xsl:param name="url"/>
    <xsl:choose>
      <xsl:when test="contains($url,'#')">
        <func:result select="f:url(substring-before($url,'#'))"/>
      </xsl:when>
      <xsl:otherwise>
        <func:result select="f:url($url)"/>
      </xsl:otherwise>
    </xsl:choose>
  </func:function>

  <!-- bookml options -->
  <xsl:variable name="BOOKML_OPTIONS">
    <!-- expected: <?latexml package="bookml" options="$options"?> -->
    <xsl:variable name="start"
      select="'package=&quot;bookml&quot; options=&quot;'"/>
    <xsl:variable name="pi"
      select="/processing-instruction('latexml')[starts-with(.,$start)]"/>
    <xsl:variable name="opts" select="substring-after($pi,$start)"/>
    <xsl:if test="$opts">
      <!-- surround with commas, remove trailing quote -->
      <xsl:value-of select=
        "substring($opts,1,string-length($opts)-1)"/>
    </xsl:if>
  </xsl:variable>

  <!-- check if option $opt was passed to bookml -->
  <func:function name="b:if-option">
    <xsl:param name="opt"/>
    <func:result
      select="b:in-list($BOOKML_OPTIONS,$opt,',')"/>
  </func:function>

  <!-- find the next version separator -->
  <func:function name="b:version-sep">
    <xsl:param name="v"/>
    <xsl:variable name="head" select="substring($v,1,1)"/>
    <xsl:variable name="tail" select="substring($v,2)"/>
    <xsl:if test="$v">
      <func:result
        select="f:if(contains('.-+=',$head),$head,b:version-sep($tail))"/>
    </xsl:if>
  </func:function>

  <!-- pick out the major version -->
  <!-- returns -2 for the empty string, -1 for a non-decimal string -->
  <func:function name="b:version-major">
    <xsl:param name="v"/>
    <xsl:variable name="sep" select="b:version-sep($v)"/>
    <xsl:variable name="head"
      select="f:if($sep!='',substring-before($v,$sep),$v)"/>
    <func:result
      select="f:if(number($head)=number($head),
                number($head),
                f:if($head!='',-1,-2))"/>
  </func:function>

  <!-- pick out the version numbers after the major -->
  <func:function name="b:version-tail">
    <xsl:param name="v"/>
    <xsl:variable name="sep" select="b:version-sep($v)"/>
    <func:result select="f:if($sep!='',substring-after($v,$sep),'')"/>
  </func:function>

  <!-- return whether $v1 <= $v2 -->
  <func:function name="b:version-leq">
    <xsl:param name="v1"/>
    <xsl:param name="v2"/>
    <!-- 'or' in not guaranteed to short circuit!
         use <xsl:choose> to avoid infinite recursion -->
    <xsl:choose>
      <xsl:when test="$v1=$v2 or
                      b:version-major($v1) &lt; b:version-major($v2)">
        <func:result select="true()"/>
      </xsl:when>
      <xsl:otherwise>
        <func:result
          select="b:version-major($v1) = b:version-major($v2) and
                  b:version-leq(b:version-tail($v1),b:version-tail($v2))"/>
      </xsl:otherwise>
    </xsl:choose>
  </func:function>

  <!-- test that the LaTeXML version is at most $v -->
  <func:function name="b:max-version">
    <xsl:param name="v"/>
    <func:result select="b:version-leq($v,$LATEXML_VERSION)"/>
  </func:function>

</xsl:stylesheet>
