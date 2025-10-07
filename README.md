# BookML
Automated LaTeX to [bookdown](https://bookdown.org/yihui/bookdown/html.html#gitbook-style)-style HTML and SCORM, powered by [LaTeXML](https://dlmf.nist.gov/LaTeXML/).

[![](https://img.shields.io/github/v/release/vlmantova/bookml?logo=github&display_name=release)](https://github.com/vlmantova/bookml/releases/latest)
![](https://img.shields.io/github/downloads/vlmantova/bookml/total?logo=github)
![](https://img.shields.io/github/license/vlmantova/bookml?logo=github)

BookML is a small wrapper around [LaTeXML](https://dlmf.nist.gov/LaTeXML/) for the production of accessible HTML content straight from LaTeX files, and for packaging it as SCORM. Created by and maintained for maths lecturers at the University of Leeds. Its main features:
- simple installation: simply drop the `bookml` directory next to the files to be compiled and copy `GNUmakefile` in the same place (well, uhm, that is a bit of a lie: you need to install LaTeXML first!)
- accessible and mobile friendly output: virtually identical to the [GitBook style](https://bookdown.org/yihui/bookdown/html.html#gitbook-style) of [bookdown](https://bookdown.org), including font selection and dark mode, tweaked to meet the [Web Content Accessibility Guidelines 2.1](https://www.w3.org/TR/WCAG21/) level AA
- fully automated (re-)compilation based on which files have changed on disk, powered by [GNU make](https://www.gnu.org/software/make/): just run
  ```shell
  make
  ```
  to zip together all PDF and HTML outputs from all the main `.tex` files in the directory (one package per main `.tex` file)
- high quality conversion of external EPS and PDF figures to SVG via [dvisvgm](https://dvisvgm.de), rather than ImageMagick used by LaTeXML
- transparent generation of SVG images from [Ti*k*Z](https://tikz.net/) pictures, [`animate`](https://ctan.org/pkg/animate) animations, Xy-matrices, and virtually any other picture-like environment: just add a few lines of code in the preamble
  ```latex
  \usepackage{bookml/bookml}
  \bmlImageEnvironment{tikzpicture,animate}
  \iflatexml\else % prevent LaTeXML from even trying to load TikZ
  \usepackage{tikz}
  \usepackage{animate}
  \fi
  ```
- alternative text for images straight from LaTeX:
  ```latex
  \usepackage{bookml/bookml}\bmlImageEnvironment{tikzpicture}
  ...
  \begin{tikzpicture} ... \end{tikzpicture}\bmlDescription{Textual description of the TikZ picture}
  % alt= option for \includegraphics requires LaTeXML 0.8.7
  \includegraphics[alt={Text description of the figure}]{figure}
  ```
- arbitrary HTML content in LaTeX, such as collapsible tags:
  ```latex
  \usepackage{bookml/bookml}
  ...
  \<details>
    \<summary>\textbf{Solution.}\</summary>
    To create a collapsible `proof' environment, ...
  \</details>
  ```
- declare alternative PDF versions (for instance sans serif, large print):
  ```latex
  \bmlAltFormat{PDF (large print)}{notes-large-print.pdf}
  % you must provide notes-large-print.tex
  ```
  the files will be automatically compiled and included in the 'Download' menu of bookdown (see the [example](https://github.com/vlmantova/bookml/releases/latest/download/example.zip) for more info)
- [SCORM](https://scorm.com/) support: running `make` creates valid `SCORM.*.zip` packages supported by most Learning Management Systems (if not, please submit an issue!)

## Examples

- [The Leeds BookML guide](https://vlmantova.github.io/bookmlleeds/)
- [forall $`x`$: Calgary](https://forallx.openlogicproject.org/html/) by Richard Zach
- [Representation Theory. A Categorical Approach](https://www.maths.lancs.ac.uk/~grabowsj/rtaca/) by Jan E. Grabowski

## Getting started

### Running locally on your device (via make)

1. Install the [prerequisites](#prerequisites).
2. **Install/upgrade:** unpack the latest [BookML release](https://github.com/vlmantova/bookml/releases) and put the `bookml` directory next to your `.tex` files.
3. **First time only:** copy `bookml/GNUmakefile` next to your `.tex` files.
4. Run `make` (or `gmake`).

Or you can unpack the [template](https://github.com/vlmantova/bookml/releases/latest/download/template.zip) to start with a working minimal example.

#### Prerequisites
- [LaTeXML](https://dlmf.nist.gov/LaTeXML/get.html) (minimum 0.8.7, recommended 0.8.8 or later)
- for any image handling: the Perl module [`Image::Magick`](https://metacpan.org/pod/Image::Magick)
- for handling EPS, PDF images: [Ghostscript](https://www.ghostscript.com/)
- for BookML images (for Ti*k*Z and similar packages): [Ghostscript](https://www.ghostscript.com/), [latexmk](https://ctan.org/pkg/latexmk), [preview.sty](https://ctan.org/pkg/preview), [dvisvgm](https://ctan.org/pkg/dvisvgm) (minimum 1.6, recommended 2.7 or later)
- for automatic PDF, HTML, zip, SCORM packaging: [GNU make](https://www.gnu.org/software/make/), [latexmk](https://ctan.org/pkg/latexmk), [zip](https://sourceforge.net/projects/infozip/), optionally [texfot](https://ctan.org/pkg/texfot)

### Running locally on your device (calling latexml, latexmlpost, latexmlc directly)
You can also run BookML as a simple addition to LaTeXML. You will lose some functionality, such as conversion of EPS and PDF figures to SVG and SCORM packaging.

1. Install the [prerequisites](#prerequisites).
2. **Install/upgrade:** unpack the latest [BookML release](https://github.com/vlmantova/bookml/releases) and put the `bookml` directory next to your `.tex` files.
3. **First time only:** copy `bookml/LaTeXML-html5.xsl` next to your `.tex` files.
4. Add `\usepackage{bookml/bookml}` to each `.tex` file.
5. Run latexml, latexmlpost, or latexmlc as you normally would without BookML. You are responsible for recompiling PDF files and other alternative formats before running latexmlpost.

### GitHub and Overleaf

BookML is also available as a [GitHub action](https://github.com/marketplace/actions/compile-with-bookml). Simply add the file `.github/workflows/bookml.yaml` to the GitHub repository, or to your Overleaf project, containing the LaTeX files to be compiled.
```yaml
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Compile with BookML
        uses: vlmantova/bookml-action@v1
```
When using Overleaf, you must also synchcronize your project with a GitHub repository (requires an Overleaf Pro account).

On every push, GitHub will compile every `.tex` file containing the string `\documentclass`, then create a GitHub release containing all outputs generated by BookML. You will receive an email from GitHub on completion, unless you have changed your notification settings.

Read the [BookML action page](https://github.com/marketplace/actions/compile-with-bookml) for its configuration options.

### Docker container

BookML is also available as a Docker image. To run it in the current directory, use
```
docker run --rm -i -t -v.:/source ghcr.io/vlmantova/bookml
```

Please note that the image contains a complete copy of TeX Live 2021. For a smaller image, use one of `ghcr.io/vlmantova/bookml-basic`, `ghcr.io/vlmantova/bookml-small`, `ghcr.io/vlmantova/bookml-medium`, `ghcr.io/vlmantova/bookml`.

## Reference manual

### Package options

Certain options can be passed to BookML like with any other LaTeX packages, for instance  ```\usepackage[imagescale=1.3333]{bookml/bookml}```. The following options are available:

<dl>
<dt>style=&lt;<i>name</i>&gt;</dt>
<dd>Switch style. &lt;<i>name</i>&gt; can be <i>gitbook</i> (default), which is almost identical to the output of bookdown, <i>plain</i>, which is a tweaked version of the normal LaTeXML style, and <i>none</i> for the LaTeXML with compatibility and bug fixes only.</dd>
<dt>mathjax=&lt;<i>number</i>&gt;</dt>
<dd>Select which MathJax version to use from 2, 3 (default), 4 (<b>incomplete</b>).</dd>
<dt>nomathjax</dt>
<dd>Disable MathJax.</dd>
<dt>imagescale=X.XX</dt>
<dd>(Deprecated) Rescale all images generated via LaTeX (using <code>bmlimage</code>, see below) by the desired factor. Images are normally sized so that fonts inside the image match the font size of the browser, but there are cases where BookML is wrong, and images turn out too small or too large. When that happens, tweak <i>imagescale</i>.</dd>
<dt>nohtmlsyntax</dt>
<dd>Do not define the command <code>\<</code> used for writing HTML tags directly in TeX.</dd>
</dl>

### Package commands and environments
Loading `\usepackage{bookml/bookml}` makes the following commands available. It also loads the [latexml package](https://github.com/vlmantova/bookml/blob/main/latexml.sty), which provides additional commands such as `\iflatexml` and `\lxRequireResource`.

<dl>
<dt>\BookMLversion</dt>
<dd>The currently running version of BookML.</dd>
<dt>\bmlAltFormat{&lt;<i>file</i>&gt;}{&lt;<i>label</i>&gt;}</dt>
<dd>Compile (if necessary) and include &lt;<i>file</i>&gt; in the download menu with label &lt;<i>label</i>&gt;. An empty label removes the file from the download menu. Only available in the <i>gitbook</i> style.</dd>
<dt>\&lt;</dt>
<dd>Open or close an HTML tag, as in <code>\&lt;span class="example"&gt;some \LaTeX{} code\&lt;/span&gt;</code>. The content between the tags is normal LaTeX code. Tags will normally generate an additional <code>&lt;p&gt;...&lt;/p&gt;</code> tag, unless they can only contain 'phrasing content'. If necessary, the behaviour of each tag can be changed with the <code>\bmlHTML*Environment</code> commands.</dd>
<dt>\bmlHTMLEnvironment{&lt;<i>tag</i>&gt;}</dt>
<dd>Introduce or redefine an HTML tag environment <code>\begin{h:&lt;<i>tag</i>&gt;}[attr1=val1,...]...\end{h:&lt;<i>tag</i>&gt;}</code> and corresponding <code>\&lt;<i>tag</i>&gt;</code>.</dd>
<dt>\bmlHTMLInlineEnvironment{&lt;<i>tag</i>&gt;}</dt>
<dd>Introduce or redefine an HTML tag environment <code>\begin{h:&lt;<i>tag</i>&gt;}...\end{h:&lt;<i>tag</i>&gt;}</code> and corresponding <code>\&lt;<i>tag</i>&gt;</code> which accept phrasing content only.</dd>
<dt>\bmlRawHTML{&lt;<i>html</i>&gt;}</dt>
<dd>Insert &lt;<i>html</i>&gt; directly in the output document, after expanding all the TeX macros. When the command appears in the preamble, &lt;<i>html</i>&gt; will be part of the head and will be copied in every output page. &lt;<i>html</i>&gt; must be written in valid XML syntax, with either no namespace or the correct namespace for HTML.</dd>
<dt>\begin{bmlimage}</dt>
<dd>The body of this environment is compiled directly into an SVG image via LaTeX, instead of running through LaTeXML.</dd>
<dt>\bmlImageEnvironment{&lt;<i>env</i>&gt;}</dt>
<dd>Compile all environments &lt;<i></i>&gt; directly into SVG images via LaTeX, instead of running the body through LaTeXML. A typical use is <code>\bmlImageEnvironment{tikzpicture}</code> for when LaTeXML struggles to process Ti<i>k</i>Z figures properly or sufficiently quickly. <strong>Warning:</strong> this will not work properly when the environments are called implicitly (for instance, the package tcolorbox uses <code>\begin{tikzpicture}</code> internally to implement its theorems).</dd>
<dt>\bmlDescription{&lt;<i>text</i>&gt;}</dt>
<dd>Attach an alternative text &lt;<i>text</i>&gt; to the immediately preceding object. Only useful for images, for instance immediately after <code>\end{tikzpicture}</code>. <strong>Warning:</strong> the command must immediately follow the object; even empty spaces can cause issues.</dd>
<dt>\bmlPlusClass{&lt;<i>class</i>&gt;}</dt>
<dd>Add the CSS class &lt;<i>class</i>&gt; to the immediately preceding object (this complements <code>\lxAddClass</code> and <code>\lxWithClass</code> provided by the latexml package). <strong>Warning:</strong> the command must immediately follow the object; even empty spaces can cause issues.</dd>
<dt>\bmlDisableMathJax</dt>
<dd>Disable running MathJax on the current mathematical content. When used in an environment that generates multiple equations, it applies only to the current one.</dd>
</dl>

### Makefile options

The build process accepts configuration options via Make variables, using the syntax `VARIABLE=value`. The options can be passed in three ways:

1. In `GNUmakefile` before `include bookml/bookml.mk`. Each option must appear on its own line, without indentation.
2. On the command line as `make VARIABLE=value`.
3. To apply an option to a single output `file`, write it in `GNUmakefile` after `include bookml/bookml.mk` as `file: VARIABLE=value` on its own line, without indentation. For instance, `main.pdf: LATEXMKFLAGS=-pdflua`. **Warning:** the variable must be applied to the target it affects *immediately* or it can cause inconsistent results (see for example SPLITAT below).

Note that changing options will *not* trigger a recompilation of the files. You will typically need to run `make clean` before recompiling again. For more information about the Makefile syntax and how variables are evaluated, consult the [GNU Make manual](https://www.gnu.org/software/make/manual/).

The following options are available.

<dl>
<dt>AUX_DIR</dt>
<dd>Location of the directory containing all intermediate files generated during compilation, such as <code>.aux</code> and <code>.bbl</code> files. This option is ignored by the BookML GitHub action. Default <i>auxdir</i>.</dd>
<dt>SOURCES</dt>
<dd>Space-separated list of <code>.tex</code> files to be compiled. File names with spaces are <i>not</i> supported. Default is the list of <code>.tex</code> files in the current directory that contain the string <code>\documentclass</code> (even if appearing in a comment!).</dd>
<dt>FORMATS</dt>
<dd>Spaces-separated list of formats to be generated from SOURCES. Recognised formats are pdf, scorm, zip. Default <i>scorm zip</i>.</dd>
<dt>SPLITAT</dt>
<dd>How to split the HTML output into multiple files (chapter, section, subsection, subsubsection). Set to empty to disable splitting. See the latexmlpost manual, <code>--split</code> option, for more details. <strong>Warning:</strong> when applied to a single target, it must be applied to <code>$(AUX_DIR)/file/index.html:</code> instead of say <code>file.zip:</code>, otherwise zip and SCORM outputs will see different values. Default <i>section</i>.</dd>
<dt>DVISVGM</dt>
<dd>Command to call dvisvgm. Default <i>dvisvgm</i>.</dd>
<dt>DVISVGMFLAGS</dt>
<dd>Options to pass to dvisvgm. Default <i>--no-fonts</i>.</dd>
<dt>LATEXMK</dt>
<dd>Command to call Latexmk. Default <i>latexmk</i>.</dd>
<dt>LATEXMKFLAGS</dt>
<dd>Command options to pass to latexmk. For instance, use <code>LATEXMKFLAGS=-pdflua</code> to use LuaTeX when compiling to PDF. Please ensure that latexmk will produce a PDF rather than a DVI.</dd>
<dt>LATEXML</dt>
<dd>Command to call LaTeXML. Default <i>latexml</i>.</dd>
<dt>LATEXMLFLAGS</dt>
<dd>Options to pass to LaTeXML.</dd>
<dt>LATEXMLPOST</dt>
<dd>Command to call latexmlpost. Default <i>latexmlpost</i>.</dd>
<dt>LATEXMLPOSTFLAGS</dt>
<dd>Options to pass to latexmlpost. <strong>Warning:</strong> when applied to a single target, it must be applied to <code>$(AUX_DIR)/file/index.html:</code> instead of say <code>file.zip:</code>, just like for SPLITAT.</dd>
<dt>PERL</dt>
<dd>Command to call Perl. Default <i>perl</i>.</dd>
<dt>TEXFOT</dt>
<dd>Command to call tex. Default <i>texfot</i>.</dd>
<dt>TEXFOTFLAGS</dt>
<dd>Options to pass to texfot.</dd>
<dt>ZIP</dt>
<dd>Command to call zip. Default <i>zip</i> (or <i>miktex-zip</i> if zip.exe is not available on Windows).</dd>
</dl>

### Makefile targets
The following targets can be used as arguments when calling `make`, for instance `make zip`.

<dl>
<dt>all</dt>
<dd>Compile all targets, based on the content of SOURCES, FORMATS, and TARGETS. This is the default target.</dd>
<dt>clean</dt>
<dd>Delete all compilation products, based on SOURCES, FORMATS, and TARGETS.</dd>
<dt>detect</dt>
<dd>Detect the versions of all the software required to run BookML and print them.</dd>
<dt>html</dt>
<dd>Compile all SOURCES to HTML. The outputs will be in the <code>$(AUX_DIR)/html</code> directory.</dd>
<dt>pdf</dt>
<dd>Compile all SOURCES to PDF. The outputs will be in the current directory, including the SyncTeX files.</dd>
<dt>scorm</dt>
<dd>Compile all SOURCES to SCORM. The outputs will be in the current directory.</dd>
<dt>xml</dt>
<dd>Compile all SOURCES to XML. The outputs will be in the <code>$(AUX_DIR)/xml</code> directory.</dd>
<dt>zip</dt>
<dd>Compile all SOURCES to zip. The outputs will be in the current directory.</dd>
</dl>
