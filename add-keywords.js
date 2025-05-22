const fs = require("fs");
const path = require("path");
const { JSDOM } = require("jsdom");

const keyword = process.argv[2];
const rootDir = process.argv[3];

if (!keyword || !rootDir) {
  console.error("Неправильные параметры: node add-keyword.js <keyword> <directory>");
  process.exit(1);
}

function insertKeyword(text, keyword) {
  const words = text.split(/\s+/);
  if (words.length < 4) return text;
  const i = Math.floor(Math.random() * words.length);
  words.splice(i, 0, keyword);
  return words.join(" ");
}

function insertKeywordInTextNodes(node, keyword) {
  node.childNodes.forEach(child => {
    if (child.nodeType === 3) { 
      child.nodeValue = insertKeyword(child.nodeValue, keyword);
    } else if (child.nodeType === 1) {
      insertKeywordInTextNodes(child, keyword);
    }
  });
}

function shouldProcessElement(el) {
  const tag = el.tagName.toLowerCase();

  if (["h1", "h2", "h3", "h4"].includes(tag)) {
    return Math.random() < 0.5;
  }

  const textTags = ["p", "span", "div", "article", "section", "li", "a", "blockquote"];
  if (textTags.includes(tag)) {
    return el.textContent.trim().length > 30;
  }

  if (el.textContent.trim().length > 30) {
    return Math.random() < 0.3;
  }

  return false;
}

function processFile(filePath) {
  const html = fs.readFileSync(filePath, "utf8");
  const dom = new JSDOM(html);
  const doc = dom.window.document;

  function walkAndInsert(el) {
    if (shouldProcessElement(el)) {
      insertKeywordInTextNodes(el, keyword);
    }
    for (const child of el.children) {
      walkAndInsert(child);
    }
  }

  doc.querySelectorAll("h1,h2,h3,h4").forEach(el => {
    if (Math.random() < 0.5) {
      el.textContent = insertKeyword(el.textContent, keyword);
    }
  });

  walkAndInsert(doc.body);

  fs.writeFileSync(filePath, dom.serialize(), "utf8");
}

function walk(dir) {
  fs.readdirSync(dir).forEach(entry => {
    const fullPath = path.join(dir, entry);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      walk(fullPath);
    } else if (entry.endsWith(".html")) {
      processFile(fullPath);
    }
  });
}

walk(rootDir);
