{
  let config = () => {
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

    // adjust characters based on Unicode variation sequences
    const replacements = {
      // MathJax renders the empty set as the U+FE00 variant, so the plain character needs adjusting
      '∅': { variant: 'variant' },
      // MathJax renders script characters in rounded style, which is fine for no variation and U+FE01
      '𝒜\xFE00': { text: 'A', variant: 'tex-caligraphic' },
      'ℬ\xFE00': { text: 'B', variant: 'tex-caligraphic' },
      '𝒞\xFE00': { text: 'C', variant: 'tex-caligraphic' },
      '𝒟\xFE00': { text: 'D', variant: 'tex-caligraphic' },
      'ℰ\xFE00': { text: 'E', variant: 'tex-caligraphic' },
      'ℱ\xFE00': { text: 'F', variant: 'tex-caligraphic' },
      '𝒢\xFE00': { text: 'G', variant: 'tex-caligraphic' },
      'ℋ\xFE00': { text: 'H', variant: 'tex-caligraphic' },
      'ℐ\xFE00': { text: 'I', variant: 'tex-caligraphic' },
      '𝒥\xFE00': { text: 'J', variant: 'tex-caligraphic' },
      '𝒦\xFE00': { text: 'K', variant: 'tex-caligraphic' },
      'ℒ\xFE00': { text: 'L', variant: 'tex-caligraphic' },
      'ℳ\xFE00': { text: 'M', variant: 'tex-caligraphic' },
      '𝒩\xFE00': { text: 'N', variant: 'tex-caligraphic' },
      '𝒪\xFE00': { text: 'O', variant: 'tex-caligraphic' },
      '𝒫\xFE00': { text: 'P', variant: 'tex-caligraphic' },
      '𝒬\xFE00': { text: 'Q', variant: 'tex-caligraphic' },
      'ℛ\xFE00': { text: 'R', variant: 'tex-caligraphic' },
      '𝒮\xFE00': { text: 'S', variant: 'tex-caligraphic' },
      '𝒯\xFE00': { text: 'T', variant: 'tex-caligraphic' },
      '𝒰\xFE00': { text: 'U', variant: 'tex-caligraphic' },
      '𝒱\xFE00': { text: 'V', variant: 'tex-caligraphic' },
      '𝒲\xFE00': { text: 'W', variant: 'tex-caligraphic' },
      '𝒳\xFE00': { text: 'X', variant: 'tex-caligraphic' },
      '𝒴\xFE00': { text: 'Y', variant: 'tex-caligraphic' },
      '𝒵\xFE00': { text: 'Z', variant: 'tex-caligraphic' }
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
