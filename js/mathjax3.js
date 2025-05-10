MathJax = {
  startup: {
    ready: () => {
      /*** adjust TeX spacing to treat identifier-like characters within <mo> as operators ***/
      const MmlMo = MathJax._.core.MmlTree.MmlNodes.mo.MmlMo;
      const OperatorDictionary = MathJax._.core.MmlTree.OperatorDictionary;

      MmlMo.prototype.checkOperatorTable = function (mo) {
        let [form1, form2, form3] = this.handleExplicitForm(this.getForms());
        this.attributes.setInherited('form', form1);
        let OPTABLE = this.constructor.OPTABLE;
        let def = OPTABLE[form1][mo] || OPTABLE[form2][mo] || OPTABLE[form3][mo];
        if (def) {
          if (this.getProperty('texClass') === undefined) {
            this.texClass = def[2];
          }
          for (const name of Object.keys(def[3] || {})) {
            this.attributes.setInherited(name, def[3][name]);
          }
          this.lspace = (def[0] + 1) / 18;
          this.rspace = (def[1] + 1) / 18;
        } else {
          let range = OperatorDictionary.getRange(mo);
          // changed here: apply TeX class only for 'mo' elements
          if (range && range[3] == 'mo') {
            if (this.getProperty('texClass') === undefined) {
              this.texClass = range[2];
            }
            const spacing = this.constructor.MMLSPACING[range[2]];
            this.lspace = (spacing[0] + 1) / 18;
            this.rspace = (spacing[1] + 1) / 18;
          }
        }
      };

      /*** do not process equations disabled with \bmlDisableMathJax (code suggested by Davide P. Cervone) ***/
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

      /*** preprocess MathML to make MathJax aware of certain LaTeXML and BookML additional info ***/
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

      /*** adjust characters based on Unicode variation sequences ***/
      const replacements = {
        // MathJax renders the empty set as the U+FE00 variant, so the plain character needs adjusting
        '∅': { variant: 'variant' },
      };

      // MathJax renders script characters in rounded style, which is fine for no variation and U+FE01
      for (const letter in script2latin) {
        replacements[letter + '\uFE00'] = { text: script2latin[letter], variant: 'tex-calligraphic' };
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
