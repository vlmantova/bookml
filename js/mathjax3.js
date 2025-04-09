MathJax = {
  startup: {
    ready: () => {
      // do not process equations disabled with \bmlDisableMathJax (code suggested by Davide P. Cervone)
      class bmlFindMathML extends MathJax._.input.mathml.FindMathML.FindMathML {
        processMath(set) {
          const adaptor = this.adaptor;
          for (const node of set.values()) {
            if (adaptor.hasClass(node, 'bml_disable_mathjax')) {
              set.delete(node);
            }
          }
          return super.processMath(set);
        }
      }

      MathJax._.components.global.combineDefaults(MathJax.config, 'mml', {FindMathML: new bmlFindMathML()});

      MathJax.startup.defaultReady();

      // preprocess MathML to make MathJax aware of certain LaTeXML and BookML additional info
      const mmlFilters = MathJax.startup.input[0].mmlFilters;

      // convert the LaTeXML calligraphic (chancery) annotation to a form MathJax understands
      // since the corresponding Unicode characters render as script (rounded)
      const script2latin = {
        '𝒜': 'A', 'ℬ': 'B', '𝒞': 'C', '𝒟': 'D', 'ℰ': 'E', 'ℱ': 'F', '𝒢': 'G',
        'ℋ': 'H', 'ℐ': 'I', '𝒥': 'J', '𝒦': 'K', 'ℒ': 'L', 'ℳ': 'M', '𝒩': 'N',
        '𝒪': 'O', '𝒫': 'P', '𝒬': 'Q', 'ℛ': 'R', '𝒮': 'S', '𝒯': 'T', '𝒰': 'U',
        '𝒱': 'V', '𝒲': 'W', '𝒳': 'X', '𝒴': 'Y', '𝒵': 'Z',
      };

      mmlFilters.add((args) => {
        for (const n of args.data.getElementsByClassName('ltx_font_mathcaligraphic')) {
          n.classList.add('MJX-tex-calligraphic');
          const letter = script2latin[n.textContent];
          if (letter !== undefined) { n.textContent = letter; }
        }
      });

      // adjust characters based on Unicode variation sequences
      const replacements = {
        // MathJax renders the empty set as the U+FE00 variant, so the plain character needs adjusting
        '∅': { variant: 'variant' },
        // MathJax renders script characters in rounded style, which is fine for no variation and U+FE01
        '𝒜\xFE00': { text: 'A', variant: 'tex-calligraphic' },
        'ℬ\xFE00': { text: 'B', variant: 'tex-calligraphic' },
        '𝒞\xFE00': { text: 'C', variant: 'tex-calligraphic' },
        '𝒟\xFE00': { text: 'D', variant: 'tex-calligraphic' },
        'ℰ\xFE00': { text: 'E', variant: 'tex-calligraphic' },
        'ℱ\xFE00': { text: 'F', variant: 'tex-calligraphic' },
        '𝒢\xFE00': { text: 'G', variant: 'tex-calligraphic' },
        'ℋ\xFE00': { text: 'H', variant: 'tex-calligraphic' },
        'ℐ\xFE00': { text: 'I', variant: 'tex-calligraphic' },
        '𝒥\xFE00': { text: 'J', variant: 'tex-calligraphic' },
        '𝒦\xFE00': { text: 'K', variant: 'tex-calligraphic' },
        'ℒ\xFE00': { text: 'L', variant: 'tex-calligraphic' },
        'ℳ\xFE00': { text: 'M', variant: 'tex-calligraphic' },
        '𝒩\xFE00': { text: 'N', variant: 'tex-calligraphic' },
        '𝒪\xFE00': { text: 'O', variant: 'tex-calligraphic' },
        '𝒫\xFE00': { text: 'P', variant: 'tex-calligraphic' },
        '𝒬\xFE00': { text: 'Q', variant: 'tex-calligraphic' },
        'ℛ\xFE00': { text: 'R', variant: 'tex-calligraphic' },
        '𝒮\xFE00': { text: 'S', variant: 'tex-calligraphic' },
        '𝒯\xFE00': { text: 'T', variant: 'tex-calligraphic' },
        '𝒰\xFE00': { text: 'U', variant: 'tex-calligraphic' },
        '𝒱\xFE00': { text: 'V', variant: 'tex-calligraphic' },
        '𝒲\xFE00': { text: 'W', variant: 'tex-calligraphic' },
        '𝒳\xFE00': { text: 'X', variant: 'tex-calligraphic' },
        '𝒴\xFE00': { text: 'Y', variant: 'tex-calligraphic' },
        '𝒵\xFE00': { text: 'Z', variant: 'tex-calligraphic' }
      };

      mmlFilters.add((args) => {
        let nodes = document.evaluate('.//m:mi | .//m:mn | .//m:mo | .//m:ms', args.data,
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
      });
    }
  }
};

{
  let script = document.createElement('script');
  // CHTML on WebKit misaligns characters by one pixel due to rounding issues
  script.setAttribute('src', 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/mml-' +
    (window.matchMedia('(-webkit-transform-2d)').matches ? 'svg' : 'chtml') + '.js');
  script.setAttribute('async', '');
  script.setAttribute('id', 'MathJax-script');
  document.body.appendChild(script);
}
