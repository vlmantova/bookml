{
  // convert the LaTeXML calligraphic (chancery) annotation to a form MathJax understands
  // since the corresponding Unicode characters render as script (rounded)
  const script2latin = {
    '𝒜': 'A', 'ℬ': 'B', '𝒞': 'C', '𝒟': 'D', 'ℰ': 'E', 'ℱ': 'F', '𝒢': 'G',
    'ℋ': 'H', 'ℐ': 'I', '𝒥': 'J', '𝒦': 'K', 'ℒ': 'L', 'ℳ': 'M', '𝒩': 'N',
    '𝒪': 'O', '𝒫': 'P', '𝒬': 'Q', 'ℛ': 'R', '𝒮': 'S', '𝒯': 'T', '𝒰': 'U',
    '𝒱': 'V', '𝒲': 'W', '𝒳': 'X', '𝒴': 'Y', '𝒵': 'Z',
  };

  // adjust characters based on Unicode variation sequences
  const replacements = {
    // MathJax renders the empty set as the U+FE00 variant, so the plain character needs adjusting
    '∅': { alternate: '1' },
    // MathJax renders script characters in rounded style, which is fine for no variation and U+FE01
    '𝒜\uFE00': { text: 'A', variant: '-tex-calligraphic' },
    'ℬ\uFE00': { text: 'B', variant: '-tex-calligraphic' },
    '𝒞\uFE00': { text: 'C', variant: '-tex-calligraphic' },
    '𝒟\uFE00': { text: 'D', variant: '-tex-calligraphic' },
    'ℰ\uFE00': { text: 'E', variant: '-tex-calligraphic' },
    'ℱ\uFE00': { text: 'F', variant: '-tex-calligraphic' },
    '𝒢\uFE00': { text: 'G', variant: '-tex-calligraphic' },
    'ℋ\uFE00': { text: 'H', variant: '-tex-calligraphic' },
    'ℐ\uFE00': { text: 'I', variant: '-tex-calligraphic' },
    '𝒥\uFE00': { text: 'J', variant: '-tex-calligraphic' },
    '𝒦\uFE00': { text: 'K', variant: '-tex-calligraphic' },
    'ℒ\uFE00': { text: 'L', variant: '-tex-calligraphic' },
    'ℳ\uFE00': { text: 'M', variant: '-tex-calligraphic' },
    '𝒩\uFE00': { text: 'N', variant: '-tex-calligraphic' },
    '𝒪\uFE00': { text: 'O', variant: '-tex-calligraphic' },
    '𝒫\uFE00': { text: 'P', variant: '-tex-calligraphic' },
    '𝒬\uFE00': { text: 'Q', variant: '-tex-calligraphic' },
    'ℛ\uFE00': { text: 'R', variant: '-tex-calligraphic' },
    '𝒮\uFE00': { text: 'S', variant: '-tex-calligraphic' },
    '𝒯\uFE00': { text: 'T', variant: '-tex-calligraphic' },
    '𝒰\uFE00': { text: 'U', variant: '-tex-calligraphic' },
    '𝒱\uFE00': { text: 'V', variant: '-tex-calligraphic' },
    '𝒲\uFE00': { text: 'W', variant: '-tex-calligraphic' },
    '𝒳\uFE00': { text: 'X', variant: '-tex-calligraphic' },
    '𝒴\uFE00': { text: 'Y', variant: '-tex-calligraphic' },
    '𝒵\uFE00': { text: 'Z', variant: '-tex-calligraphic' }
  };

  MathJax = {
    mml: {
      allowHtmlInTokenNodes: true,
      mmlFilters: [
        (args) => {
          for (const n of args.data.getElementsByClassName('ltx_font_mathcaligraphic')) {
            n.setAttribute('data-mjx-variant', '-tex-calligraphic');
            const letter = script2latin[n.textContent];
            if (letter !== undefined) { n.textContent = letter; }
          }
        },
        (args) => {
          let nodes = document.evaluate('.//m:mi | .//m:mn | .//m:mo | .//m:ms', args.data,
            () => 'http://www.w3.org/1998/Math/MathML', XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE);
          for (let i = 0; i < nodes.snapshotLength; i++) {
            const n = nodes.snapshotItem(i);
            const repl = replacements[n.innerHTML];
            if (repl !== undefined) {
              const text = repl['text'];
              for (attribute in repl) {
                if (attribute !== 'text') { n.setAttribute('data-mjx-' + attribute, repl[attribute]); }
              }
              if (text !== undefined) { n.innerHTML = text; }
            }
          }
        },
      ],
    },
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
      }
    }
  };

  let script = document.createElement('script');
  script.setAttribute('src', 'https://cdn.jsdelivr.net/npm/mathjax@4/mml-chtml.js');
  script.setAttribute('async', '');
  script.setAttribute('id', 'MathJax-script');
  document.body.appendChild(script);
}
