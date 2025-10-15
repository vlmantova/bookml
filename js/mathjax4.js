{
  /*** convert the LaTeXML calligraphic (chancery) annotation to a form MathJax understands ***/
  const script2latin = {
    '𝒜': 'A', 'ℬ': 'B', '𝒞': 'C', '𝒟': 'D', 'ℰ': 'E', 'ℱ': 'F', '𝒢': 'G',
    'ℋ': 'H', 'ℐ': 'I', '𝒥': 'J', '𝒦': 'K', 'ℒ': 'L', 'ℳ': 'M', '𝒩': 'N',
    '𝒪': 'O', '𝒫': 'P', '𝒬': 'Q', 'ℛ': 'R', '𝒮': 'S', '𝒯': 'T', '𝒰': 'U',
    '𝒱': 'V', '𝒲': 'W', '𝒳': 'X', '𝒴': 'Y', '𝒵': 'Z',
  };

  const filterLaTeXMLCalligraphic = (args) => {
    for (const n of args.data.getElementsByClassName('ltx_font_mathcaligraphic')) {
      n.setAttribute('data-mjx-variant', '-tex-calligraphic');
      const letter = script2latin[n.textContent];
      if (letter !== undefined) { n.textContent = letter; }
    }
  };

  /*** adjust characters based on Unicode variation sequences ***/
  const replacements = {
    // MathJax renders the empty set as the U+FE00 variant, so the plain character needs adjusting
    '∅': { alternate: '1' },
  };

  // MathJax renders script characters in rounded style, which is fine for no variation and U+FE01
  for (const letter in script2latin) {
    replacements[letter + '\uFE00'] = { text: script2latin[letter], variant: '-tex-calligraphic' };
  };

  const filterUnicodeVariationSequences = (args) => {
    let nodes = document.evaluate('.//m:mi | .//m:mn | .//m:mo | .//m:ms', args.data,
      () => 'http://www.w3.org/1998/Math/MathML', XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE);
    for (let i = 0; i < nodes.snapshotLength; i++) {
      const n = nodes.snapshotItem(i);
      const repl = replacements[n.innerHTML];
      if (repl !== undefined) {
        n.removeAttribute('mathvariant');
        const text = repl['text'];
        for (attribute in repl) {
          if (attribute !== 'text') { n.setAttribute('data-mjx-' + attribute, repl[attribute]); }
        }
        if (text !== undefined) { n.innerHTML = text; }
      }
    };
  };

  MathJax = {
    loader: {
      'output/svg': {
        ready() {
          /*** workaround SVG renderer issue with inline breaks (code provided by Davide P. Cervone) ***/
          if (MathJax.version === '4.0.0') {
            const { SvgSemantics } = MathJax._.output.svg.Wrappers.semantics;
            SvgSemantics.prototype.getBreakNode = function (bbox) {
              if (!bbox.start) return [this, null];
              const [i, j] = bbox.start;
              const childNodes = this.childNodes[0].childNodes;
              if (!childNodes[i]) return [this, null];
              return childNodes[i].getBreakNode(childNodes[i].getLineBBox(j));
            }
          }
        }
      }
    },
    mml: {
      allowHtmlInTokenNodes: true,
      mmlFilters: [
        filterLaTeXMLCalligraphic,
        filterUnicodeVariationSequences,
      ],
    },
    output: {
      linebreaks: {
        inline: false, // temporarily disabled due to incompatibility with LaTeXML's equation groups via tables
      },
    },
    startup: {
      ready: () => {
        /*** adjust TeX spacing to treat identifier-like characters within <mo> as operators ***/
        const MmlMo = MathJax._.core.MmlTree.MmlNodes.mo.MmlMo;
        const OperatorDictionary = MathJax._.core.MmlTree.OperatorDictionary;
        const getRange = OperatorDictionary.getRange;
        const OPDEF = OperatorDictionary.OPDEF;
        const TEXCLASS = MathJax._.core.MmlTree.MmlNode.TEXCLASS;

        MmlMo.prototype.getOperatorDef = function (mo) {
          const [form1, form2, form3] = this.handleExplicitForm(this.getForms());
          this.attributes.setInherited('form', form1);
          const CLASS = this.constructor;
          const OPTABLE = CLASS.OPTABLE;
          const def = OPTABLE[form1][mo] || OPTABLE[form2][mo] || OPTABLE[form3][mo];
          if (def) {
            return def;
          }
          this.setProperty('noDictDef', true);
          const limits = this.attributes.get('movablelimits');
          const isOP = !!mo.match(CLASS.opPattern);
          if ((isOP || limits) && this.getProperty('texClass') === undefined) {
            return OPDEF(1, 2, TEXCLASS.OP);
          }
          const range = getRange(mo);
          // changed here: use REL TeX class for non-mo elements
          const texClass = range && range[3] == 'mo' ? range[2] : TEXCLASS.REL;
          const [l, r] = CLASS.MMLSPACING[texClass];
          return OPDEF(l, r, texClass);
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
      }
    }
  };

  let script = document.createElement('script');
  script.setAttribute('src', 'https://cdn.jsdelivr.net/npm/mathjax@4/mml-chtml.js');
  script.setAttribute('async', '');
  script.setAttribute('id', 'MathJax-script');
  document.body.appendChild(script);
}
