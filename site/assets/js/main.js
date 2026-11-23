(() => {
  // Mobile navigation toggle
  const navToggle = document.querySelector(".nav-toggle");
  const siteNav = document.getElementById("primary-nav");

  if (navToggle && siteNav) {
    navToggle.addEventListener("click", () => {
      const isOpen = siteNav.classList.toggle("open");
      navToggle.setAttribute("aria-expanded", String(isOpen));
    });

    siteNav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        siteNav.classList.remove("open");
        navToggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  // Dynamic footer year
  const yearEl = document.querySelector("[data-current-year]");
  if (yearEl) {
    yearEl.textContent = String(new Date().getFullYear());
  }

  // Print / Save as PDF button on the Privacy Policy page
  const printBtn = document.querySelector("[data-print-policy]");
  if (printBtn) {
    printBtn.addEventListener("click", () => window.print());
  }

  // Highlight active Table of Contents section on scroll
  const tocLinks = Array.from(document.querySelectorAll(".toc-list a[href^='#']"));
  if (tocLinks.length > 0 && "IntersectionObserver" in window) {
    const sections = tocLinks
      .map((link) => document.querySelector(link.getAttribute("href")))
      .filter(Boolean);

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.find((entry) => entry.isIntersecting);
        if (!visible) return;
        const activeId = `#${visible.target.id}`;
        tocLinks.forEach((link) => {
          link.classList.toggle("active", link.getAttribute("href") === activeId);
        });
      },
      { rootMargin: "-96px 0px -70% 0px", threshold: 0 }
    );

    sections.forEach((section) => observer.observe(section));
  }
})();
