
// From: https://github.com/cldellow/datasette-ui-extras/blob/main/datasette_ui_extras/static/sticky-table-headers.js

// Solution from https://medium.com/neocoast/fixing-a-table-header-on-a-horizontally-scrolling-table-de3364610957

(function () {
  function configureScrolling() {
    const scrolling = document.querySelector('.rows-and-columns');
    const thead = document.querySelector('.rows-and-columns thead');

    if (!scrolling || !thead)
      return;

    const translate = () => {
      const scroll = window.scrollY;
      const headerTop = scrolling.offsetTop;

      if (scroll > headerTop) {
        const yTranslation = Math.floor(Math.abs(scroll - headerTop));
        thead.style.setProperty('transform', `translateY(${yTranslation}px)`);
      } else {
        thead.style.removeProperty('transform');
      }
    }

    document.addEventListener('scroll', translate);
  }

  addEventListener('DOMContentLoaded', configureScrolling);
})();

