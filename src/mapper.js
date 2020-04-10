const schemas = require('./schemas');

class Mapper {
  constructor(opt, menu, buffer, isTriggerCharacter = false) {
    this.items = [];
    this.input = opt.input;
    this.bufnr = opt.bufnr;
    this.line = opt.line;
    this.menu = menu;
    this.buffer = buffer;
    this.tableScope = this.findTableScope();
    this.bufferTableScope = this.buffer && this.buffer.table;
    this.isTriggerCharacter = isTriggerCharacter;
    this.charBefore = this.line.charAt(opt.col - 1)
  }

  add(word, type) {
    if (type !== 'column') {
      if (this.isMatch(word)) {
        this.addCompleteItem(word, type);
      }
      return;
    }

    if (this.tableScope) {
      if (this.isTableMatch(word, this.tableScope)) {
        this.addCompleteItem(word[1], this.tableScope);
      }
      return;
    }

    if (this.bufferTableScope) {
      if (this.isTableMatch(word, this.bufferTableScope)) {
        this.addCompleteItem(word[1], this.bufferTableScope);
      }
      return;
    }

    if (this.isMatch(word[1])) {
      this.addCompleteItem(word[1], type)
    }
  }

  addCompleteItem(word, info) {
    this.items.push({
      menu: this.menu,
      info,
      word: this.quote(word),
      abbr: word,
    })
  }

  quote(word) {
    if (!this.buffer || !schemas[this.buffer.scheme] || !schemas[this.buffer.scheme].quote) {
      return word;
    }

    if (/[A-Z]/.test(word)) {
      return `${this.charBefore !== '"' ? '"' : ''}${word}"`;
    }

    return word;
  }

  isMatch(word) {
    return this.isTriggerCharacter || this.input[0].toLowerCase() === word[0].toLowerCase();
  }

  isTableMatch(word, table) {
    const alias = this.buffer && this.buffer.aliases[word[0]];
    const isTableMatch = word[0] === table || (alias && alias === table);
    return isTableMatch && this.isMatch(word[1]);
  }

  findTableScope() {
    const table_match = this.line.match(/"?(\w+)"?\."?\w*"?$/);
    if (table_match && table_match.length >= 1) {
      return table_match[1];
    }

    return null;
  }
}

module.exports = Mapper;
