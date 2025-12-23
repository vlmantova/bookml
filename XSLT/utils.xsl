<?xml version="1.0" encoding="UTF-8"?>
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
<xsl:stylesheet
    version    = "1.0"
    xmlns:xsl  = "http://www.w3.org/1999/XSL/Transform"
    xmlns:exsl = "http://exslt.org/common"
    xmlns:f    = "http://dlmf.nist.gov/LaTeXML/functions"
    xmlns:func = "http://exslt.org/functions"
    xmlns:b    = "https://vlmantova.github.io/bookml/functions"
    xmlns:ltx  = "http://dlmf.nist.gov/LaTeXML"
    xmlns:str  = "http://exslt.org/strings"
    extension-element-prefixes = "exsl func str"
    exclude-result-prefixes    = "f func b">

  <!-- global variables -->
  <xsl:param name="BMLVERSION">@VERSION@</xsl:param>

  <xsl:param name="BMLSTYLE">
    <xsl:choose>
      <xsl:when test="b:if-option('style=plain')">plain</xsl:when>
      <xsl:when test="b:if-option('style=gitbook')">gitbook</xsl:when>
      <xsl:when test="b:if-option('style=none')">none</xsl:when>
      <xsl:otherwise>gitbook</xsl:otherwise>
    </xsl:choose>
  </xsl:param>

  <xsl:variable name="GITBOOK" select="$BMLSTYLE='gitbook'"/>
  <xsl:variable name="PLAIN" select="$BMLSTYLE='plain'"/>
  <xsl:variable name="MATHJAX2" select="b:if-option('mathjax=2')"/>
  <xsl:variable name="MATHJAX4" select="b:if-option('mathjax=4')"/>
  <xsl:variable name="MATHJAX3"
    select="not(b:if-option('nomathjax') or $MATHJAX2 or $MATHJAX4)"/>

  <!-- alter $fragment by overriding mode="bml-alter" -->
  <xsl:template name="bml-alter">
    <xsl:param name="fragment"/>
    <xsl:apply-templates select="exsl:node-set($fragment)" mode="bml-alter"/>
  </xsl:template>

  <xsl:template match="@*|node()" mode="bml-alter">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="bml-alter"/>
    </xsl:copy>
  </xsl:template>

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

  <func:function name="b:lower-case">
    <xsl:param name="string" />
    <func:result select="translate($string,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')"/>
  </func:function>

  <!-- bookml options -->
  <xsl:variable name="BOOKML_OPTIONS">
    <!-- expected: <?latexml package="bookml/bookml" options="$options"?> -->
    <xsl:variable name="pkgstart"
      select="'package=&quot;bookml/bookml&quot;'"/>
    <xsl:variable name="optstart"
      select="' options=&quot;'"/>
    <xsl:variable name="pi"
      select="/processing-instruction('latexml')[starts-with(.,$pkgstart)]"/>
    <xsl:variable name="opts" select="substring-after(substring-after($pi,$pkgstart),$optstart)"/>
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
    <func:result select="b:version-leq($LATEXML_VERSION,$v)"/>
  </func:function>

  <xsl:template match="ltx:xmlelem">
    <xsl:param name="context"/>
    <xsl:choose>
      <xsl:when test="@ns">
        <xsl:element name="{@name}" namespace="{@ns}">
          <xsl:apply-templates select="ltx:xmlattr" />
          <xsl:apply-templates select="node()[not(self::ltx:xmlattr)]">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="{@name}">
          <xsl:apply-templates select="ltx:xmlattr" />
          <xsl:apply-templates select="node()[not(self::ltx:xmlattr)]">
            <xsl:with-param name="context" select="$context"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:xmlinlineelem">
    <xsl:choose>
      <xsl:when test="@ns">
        <xsl:element name="{@name}" namespace="{@ns}">
          <xsl:apply-templates select="ltx:xmlattr" />
          <xsl:apply-templates select="node()[not(self::ltx:xmlattr)]">
            <xsl:with-param name="context" select="'inline'"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="{@name}">
          <xsl:apply-templates select="ltx:xmlattr"/>
          <xsl:apply-templates select="node()[not(self::ltx:xmlattr)]">
            <xsl:with-param name="context" select="'inline'"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:xmlattr[@ns]">
    <xsl:attribute name="{@name}" namespace="{@ns}">
      <xsl:value-of select="@value"/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="ltx:xmlattr">
    <xsl:attribute name="{@name}">
      <xsl:value-of select="@value"/>
    </xsl:attribute>
  </xsl:template>

  <func:function name="b:fix-windows-paths">
    <xsl:param name="path"/>
    <func:result select="f:subst($path,'\','/')"/>
  </func:function>

  <func:function name="b:ends-with">
    <xsl:param name="haystack"/>
    <xsl:param name="needle"/>
    <func:result select="substring($haystack,string-length($haystack) - string-length($needle) + 1) = $needle"/>
  </func:function>

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
    <xsl:param name="split-options" select="str:split(b:escape-options(../@options),',')" />
    <func:result select="substring-after(($split-options/text()[starts-with(.,'page=')])[last()],'page=')" />
  </func:function>

  <func:function name="b:auto-svg-source">
    <xsl:param name="candidates" select="str:split(str:replace(.,'\','/'),',')" />

    <func:result>
      <!-- if we only have EPS/PDF candidates, pick the first, preferring EPS -->
      <xsl:if test="not($candidates//text()[not(b:ends-with(b:lower-case(.),'.eps') or b:ends-with(b:lower-case(.),'.pdf'))])">
        <xsl:variable name="eps" select="($candidates//text()[b:ends-with(b:lower-case(.),'.eps')])[1]"/>
        <xsl:choose>
          <xsl:when test="$eps != ''">
            <xsl:value-of select="$eps" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="($candidates//text()[b:ends-with(b:lower-case(.),'.pdf')])[1]" />
          </xsl:otherwise>
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

  <func:function name="b:auto-svg-candidate">
    <xsl:param name="source" select="b:auto-svg-source()"/>
    <xsl:param name="page" select="b:page-option()"/>

    <func:result>
      <xsl:if test="$source != ''">
        <!-- if $source is not below the current folder, we remove the folder, as latexmlpost would do -->
        <xsl:variable name="source-without-parent">
          <xsl:choose>
            <xsl:when test="b:is-within-cwd($source)">
              <xsl:value-of select="$source" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="str:split($source,'/')[last()]//text()" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>

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
