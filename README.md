# BookML
bookdown flavoured GitBook port for LaTeXML.

![](https://img.shields.io/github/v/release/vlmantova/bookml?logo=github&display_name=release)
![](https://img.shields.io/github/downloads/vlmantova/bookml/total?logo=github)
![](https://img.shields.io/github/license/vlmantova/bookml?logo=github)

BookML is a small add-on for [LaTeXML](https://dlmf.nist.gov/LaTeXML/) with a few accessibility features and quality of life improvements. Its purpose is to simplify the conversion of LaTeX documents into HTML files that conform to the [Web Content Accessibility Guidelines 2.1](https://www.w3.org/TR/WCAG21/) level AA.

The key features:
- a port of the [GitBook style](https://bookdown.org/yihui/bookdown/html.html#gitbook-style) of [bookdown](https://bookdown.org), tweaked for better WCAG conformance; this is enabled by default, but can be disabled;
- styling fixes for LaTeXML (many backported from 0.8.6), such as mobile friendly responsive output;
- transparent generation of SVG pictures via LaTeX for packages not well supported by LaTeXML, such as Ti*k*Z pictures, animations, Xy-matrices;
- a simple method to add alternative text for images;
- partial support for arbitrary HTML content;
- direct embedding of MathJax, with the option of choosing between versions 2 and 3 or disabling it.

## Getting started
1. Install [LaTeXML](https://dlmf.nist.gov/LaTeXML/get.html), minimum version 0.8.5, and optionally a TeX distribution including `latexmk`, `dvisvgm`, `preview.sty`.
2. [Install/upgrade] Unpack the latest [BookML release](https://github.com/vlmantova/bookml/releases) and put the `bookml` folder next to your `.tex` files.
3. [First install only] Copy the files `bookml/XSLT/LaTeXML-*.xsl` next to your `.tex` files.
4. Add `\usepackage{bookml/bookml}` to your preamble.
5. Compile your files with LaTeXML, passing the option `--navigationtoc=context` in postprocessing.

You can also use `bookml` as a git submodule, in which case make sure to run `make` to download the bookdown sources and generate all the relevant files.

The [manual](https://vlmantova.github.io/bookml/) is an example of a LaTeX file compiled in GitBook and plain style and it describes all the options and ways to customise the output.
