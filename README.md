# BookML
Automated LaTeX to [bookdown](https://bookdown.org/yihui/bookdown/html.html#gitbook-style)-style HTML and SCORM, powered by [LaTeXML](https://dlmf.nist.gov/LaTeXML/).

[![](https://img.shields.io/github/v/release/vlmantova/bookml?logo=github&display_name=release)](https://github.com/vlmantova/bookml/releases/latest)
![](https://img.shields.io/github/downloads/vlmantova/bookml/total?logo=github)
![](https://img.shields.io/github/license/vlmantova/bookml?logo=github)

BookML is a small wrapper around [LaTeXML](https://dlmf.nist.gov/LaTeXML/) for the production of accessible HTML content straight from LaTeX files, and for packaging it as SCORM. Created by and maintained for maths lecturers at the University of Leeds. Its main features:
- simple installation: simply drop the `bookml` folder next to the files to be compiled and copy `GNUmakefile` in the same place (well, uhm, that is a bit of a lie: you need to install LaTeXML first!)
- accessible and mobile friendly output: virtually identical to the [GitBook style](https://bookdown.org/yihui/bookdown/html.html#gitbook-style) of [bookdown](https://bookdown.org), including font selection and dark mode, tweaked to meet the [Web Content Accessibility Guidelines 2.1](https://www.w3.org/TR/WCAG21/) level AA
- fully automated (re-)compilation based on which files have changed on disk, powered by [GNU make](https://www.gnu.org/software/make/): just run
  ```shell
  make
  ```
  to zip together all PDF and HTML outputs from all the main `.tex` files in the folder (one package per main `.tex` file)
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
- arbitrary HTML content in LaTeX, such as foldable tags:
  ```latex
  \usepackage{bookml/bookml}
  ...
  \<DETAILS>
    \<SUMMARY>\textbf{Solution.}\</SUMMARY>
    To create a foldable `proof' environment, ...
  \</DETAILS>
  ```
- declare alternative PDF versions (for instance sans serif, large print):
  ```latex
  \bmlAltFormat{PDF (large print)}{notes-large-print.pdf}
  % you must provide notes-large-print.tex
  ```
  the files will be automatically compiled and included in the 'Download' menu of bookdown (see the [example](https://github.com/vlmantova/bookml/releases/latest/download/example.zip) for more info)
- [SCORM](https://scorm.com/) support: running `make` creates valid `SCORM.*.zip` packages supported by most Learning Management Systems (if not, please submit an issue!)

## Getting started
1. Install the [prerequisites](#prerequisites).
2. **Install/upgrade:** unpack the latest [BookML release](https://github.com/vlmantova/bookml/releases) and put the `bookml` folder next to your `.tex` files.
3. **First install only:** copy `bookml/GNUmakefile` next to your `.tex` files.
4. Run `make` (or `gmake`).

Or you can unpack the [template](https://github.com/vlmantova/bookml/releases/latest/download/template.zip) to start with a working minimal example.

The [BookML manual](https://vlmantova.github.io/bookml/) is an example of a LaTeX file compiled in GitBook and plain style and it describes all the options and ways to customise the output.

The [Leeds BookML guide](https://vlmantova.github.io/bookmlleeds/) has further examples and tips for lecturers and detailed installation instructions (some specific to the University of Leeds), including for instance how to compile exercises with and without solutions, or how to produce various alternative PDFs from the same file.

## Prerequisites
- [LaTeXML](https://dlmf.nist.gov/LaTeXML/get.html) (minimum 0.8.5, recommended 0.8.6 or later)
- for any image handling: the Perl module [`Image::Magick`](https://metacpan.org/pod/Image::Magick)
- for handling EPS, PDF images: [Ghostscript](https://www.ghostscript.com/)
- for BookML images (for Ti*k*z and similar packages): [Ghostscript](https://www.ghostscript.com/), [latexmk](https://ctan.org/pkg/latexmk), [preview.sty](https://ctan.org/pkg/preview), [dvisvgm](https://ctan.org/pkg/dvisvgm) (minimum 1.6, recommended 2.7 or later)
- for automatic PDF, HTML, zip, SCORM packaging: [GNU make](https://www.gnu.org/software/make/), [latexmk](https://ctan.org/pkg/latexmk), [zip](https://sourceforge.net/projects/infozip/), optionally [texfot](https://ctan.org/pkg/texfot)
