/**
 * Basically Brilliant Beginner - Main JavaScript
 * Handles navigation, scroll animations, and interactive elements
 */

(function() {
  'use strict';

  // --- Mobile Navigation Toggle ---
  const navToggle = document.querySelector('.nav__toggle');
  const navLinks = document.querySelector('.nav__links');

  if (navToggle && navLinks) {
    navToggle.addEventListener('click', function() {
      const isOpen = navLinks.classList.toggle('nav__links--open');
      navToggle.setAttribute('aria-expanded', isOpen);
      
      // Animate hamburger lines
      const lines = navToggle.querySelectorAll('.nav__toggle-line');
      if (isOpen) {
        lines[0].style.transform = 'rotate(45deg) translate(5px, 5px)';
        lines[1].style.opacity = '0';
        lines[2].style.transform = 'rotate(-45deg) translate(5px, -5px)';
      } else {
        lines[0].style.transform = 'none';
        lines[1].style.opacity = '1';
        lines[2].style.transform = 'none';
      }
    });

    // Close menu when clicking a link
    navLinks.querySelectorAll('.nav__link').forEach(link => {
      link.addEventListener('click', () => {
        navLinks.classList.remove('nav__links--open');
        navToggle.setAttribute('aria-expanded', 'false');
        const lines = navToggle.querySelectorAll('.nav__toggle-line');
        lines[0].style.transform = 'none';
        lines[1].style.opacity = '1';
        lines[2].style.transform = 'none';
      });
    });
  }

  // --- Smooth Scroll for Anchor Links ---
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      const targetId = this.getAttribute('href');
      if (targetId === '#') return;
      
      const target = document.querySelector(targetId);
      if (target) {
        e.preventDefault();
        const headerHeight = document.querySelector('.nav').offsetHeight;
        const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - headerHeight;
        
        window.scrollTo({
          top: targetPosition,
          behavior: 'smooth'
        });
      }
    });
  });

  // --- Scroll Reveal Animation ---
  const revealElements = document.querySelectorAll(
    '.element-card, .council-card, .team-card, .hub-card, .section__header'
  );

  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry, index) => {
      if (entry.isIntersecting) {
        setTimeout(() => {
          entry.target.classList.add('animate-in');
        }, index * 100);
        revealObserver.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  });

  revealElements.forEach(el => revealObserver.observe(el));

  // --- Parallax Hero Orbs ---
  const orbs = document.querySelectorAll('.hero__orb');
  
  if (orbs.length && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    let ticking = false;
    
    function updateOrbs() {
      const scrollY = window.pageYOffset;
      const heroHeight = document.querySelector('.hero').offsetHeight;
      const progress = Math.min(scrollY / heroHeight, 1);
      
      orbs.forEach((orb, index) => {
        const speed = 0.1 + (index * 0.05);
        const y = scrollY * speed;
        const rotate = scrollY * 0.02 * (index + 1);
        orb.style.transform = `translate3d(0, ${y}px, 0) rotate(${rotate}deg)`;
      });
      
      ticking = false;
    }
    
    window.addEventListener('scroll', () => {
      if (!ticking) {
        window.requestAnimationFrame(updateOrbs);
        ticking = true;
      }
    }, { passive: true });
  }

  // --- Active Navigation on Scroll ---
  const sections = document.querySelectorAll('section[id]');
  const navLinksAll = document.querySelectorAll('.nav__link:not(.nav__link--cta)');

  function updateActiveNav() {
    const scrollY = window.pageYOffset + 100;
    
    sections.forEach(section => {
      const sectionTop = section.offsetTop;
      const sectionHeight = section.offsetHeight;
      const sectionId = section.getAttribute('id');
      
      if (scrollY >= sectionTop && scrollY < sectionTop + sectionHeight) {
        navLinksAll.forEach(link => {
          link.classList.toggle('nav__link--active', link.getAttribute('href') === `#${sectionId}`);
        });
      }
    });
  }

  window.addEventListener('scroll', updateActiveNav, { passive: true });

  // --- Element Card Hover Effect ---
  const elementCards = document.querySelectorAll('.element-card');
  
  elementCards.forEach(card => {
    card.addEventListener('mouseenter', function() {
      this.style.setProperty('--element-color', getComputedStyle(this).getPropertyValue('--element-color'));
    });
  });

  // --- Council Card Counter Animation ---
  const statNumbers = document.querySelectorAll('[data-count]');
  
  const countObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const target = entry.target;
        const count = parseInt(target.dataset.count, 10);
        const duration = 2000;
        const step = count / (duration / 16);
        let current = 0;
        
        const timer = setInterval(() => {
          current += step;
          if (current >= count) {
            target.textContent = count;
            clearInterval(timer);
          } else {
            target.textContent = Math.floor(current);
          }
        }, 16);
        
        countObserver.unobserve(target);
      }
    });
  }, { threshold: 0.5 });

  statNumbers.forEach(el => countObserver.observe(el));

  // --- Copy to Clipboard Helper ---
  window.copyToClipboard = function(text, button) {
    navigator.clipboard.writeText(text).then(() => {
      const originalText = button.textContent;
      button.textContent = 'Copied!';
      button.style.background = 'var(--color-success)';
      setTimeout(() => {
        button.textContent = originalText;
        button.style.background = '';
      }, 2000);
    });
  };

  // --- Theme Toggle (if needed later) ---
  // const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  // document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');

  console.log('🌿 Basically Brilliant Beginner loaded');
})();