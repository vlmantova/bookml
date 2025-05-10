{
  let config = () => {
    /*** adjust TeX spacing to treat identifier-like characters within <mo> as operators ***/
    MathJax.Hub.Register.StartupHook("MathML Jax Ready", function () {
      const TEXCLASS = MathJax.ElementJax.mml.TEXCLASS;
      // changed here: TEXCLASS.REL whenever the range is marked as 'mi' or 'mn' in MathJax 3
      MathJax.ElementJax.mml.mo.prototype.RANGES = [
        [0x20, 0x7F, TEXCLASS.REL, "BasicLatin"],
        [0xA0, 0xBF, TEXCLASS.ORD, "Latin1Supplement"],
        [0xC0, 0xFF, TEXCLASS.REL, "Latin1Supplement"],
        [0x100, 0x17F, TEXCLASS.REL],
        [0x180, 0x24F, TEXCLASS.REL],
        [0x2B0, 0x2FF, TEXCLASS.ORD, "SpacingModLetters"],
        [0x300, 0x36F, TEXCLASS.ORD, "CombDiacritMarks"],
        [0x370, 0x3FF, TEXCLASS.REL, "GreekAndCoptic"],
        [0x1E00, 0x1EFF, TEXCLASS.REL],
        [0x2000, 0x206F, TEXCLASS.PUNCT, "GeneralPunctuation"],
        [0x2070, 0x209F, TEXCLASS.ORD],
        [0x20A0, 0x20CF, TEXCLASS.ORD],
        [0x20D0, 0x20FF, TEXCLASS.ORD, "CombDiactForSymbols"],
        [0x2100, 0x214F, TEXCLASS.REL, "LetterlikeSymbols"],
        [0x2150, 0x218F, TEXCLASS.REL],
        [0x2190, 0x21FF, TEXCLASS.REL, "Arrows"],
        [0x2200, 0x22FF, TEXCLASS.BIN, "MathOperators"],
        [0x2300, 0x23FF, TEXCLASS.ORD, "MiscTechnical"],
        [0x2460, 0x24FF, TEXCLASS.ORD],
        [0x2500, 0x259F, TEXCLASS.ORD],
        [0x25A0, 0x25FF, TEXCLASS.ORD, "GeometricShapes"],
        [0x2700, 0x27BF, TEXCLASS.ORD, "Dingbats"],
        [0x27C0, 0x27EF, TEXCLASS.ORD, "MiscMathSymbolsA"],
        [0x27F0, 0x27FF, TEXCLASS.REL, "SupplementalArrowsA"],
        [0x2900, 0x297F, TEXCLASS.REL, "SupplementalArrowsB"],
        [0x2980, 0x29FF, TEXCLASS.ORD, "MiscMathSymbolsB"],
        [0x2A00, 0x2AFF, TEXCLASS.BIN, "SuppMathOperators"],
        [0x2B00, 0x2BFF, TEXCLASS.ORD, "MiscSymbolsAndArrows"],
        [0x1D400, 0x1D7FF, TEXCLASS.REL]
      ];
    });

    /*** preprocess MathML to make MathJax aware of certain LaTeXML and BookML additional info ***/
    // convert the LaTeXML calligraphic (chancery) annotation to a form MathJax understands
    // since the corresponding Unicode characters render as script (rounded)
    const script2latin = {
      '𝒜': 'A', 'ℬ': 'B', '𝒞': 'C', '𝒟': 'D', 'ℰ': 'E', 'ℱ': 'F', '𝒢': 'G',
      'ℋ': 'H', 'ℐ': 'I', '𝒥': 'J', '𝒦': 'K', 'ℒ': 'L', 'ℳ': 'M', '𝒩': 'N',
      '𝒪': 'O', '𝒫': 'P', '𝒬': 'Q', 'ℛ': 'R', '𝒮': 'S', '𝒯': 'T', '𝒰': 'U',
      '𝒱': 'V', '𝒲': 'W', '𝒳': 'X', '𝒴': 'Y', '𝒵': 'Z',
    };

    MathJax.Hub.preProcessors.Add((args) => {
      for (const n of args.getElementsByClassName('ltx_font_mathcaligraphic')) {
        n.classList.add('MJX-tex-caligraphic');
        const letter = script2latin[n.textContent];
        if (letter !== undefined) { n.textContent = letter; }
      }
    }, 1);

    /*** adjust characters based on Unicode variation sequences ***/
    const replacements = {
      // MathJax renders the empty set as the U+FE00 variant, so the plain character needs adjusting
      '∅': { variant: 'variant' }
    };

    // MathJax renders script characters in rounded style, which is fine for no variation and U+FE01
    for (const letter in script2latin) {
      replacements[letter + '\uFE00'] = { text: script2latin[letter], variant: 'tex-caligraphic' };
    };

    MathJax.Hub.preProcessors.Add((args) => {
      let nodes = document.evaluate('.//m:mi | .//m:mn | .//m:mo | .//m:ms', args,
        () => 'http://www.w3.org/1998/Math/MathML', XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE);
      for (let i = 0; i < nodes.snapshotLength; i++) {
        const n = nodes.snapshotItem(i);
        const repl = replacements[n.innerHTML];
        if (repl !== undefined) {
          const variant = repl['variant'];
          const text = repl['text'];
          if (variant !== undefined) { n.classList.add('MJX-' + variant); n.removeAttribute('mathvariant'); }
          if (text !== undefined) { n.innerHTML = text; }
        }
      }
    }, 1);
  };

  let script = document.createElement('script');
  script.setAttribute('src', 'https://cdn.jsdelivr.net/npm/mathjax@2/MathJax.js?config=MML_CHTML');
  script.addEventListener('load', config);
  document.head.appendChild(script);
}
