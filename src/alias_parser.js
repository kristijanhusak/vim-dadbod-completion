const sqlReservedWords = require('./sql_reserved_words');

module.exports = (content, tables = []) => {
  const result = {};
  if (!tables.length || !content.length) {
    return result;
  }
  const tableStr = `"?(${tables.join('|')})"?`
  const regex = new RegExp(`${tableStr}\\s+(as\\s+)?"?(\\w+)"?`, 'g')
  let matches = true
  while (matches) {
    matches = regex.exec(content);
    if (matches && matches[3] && !sqlReservedWords.includes(matches[3].toLowerCase())) {
      result[matches[1]] = matches[3]
    }
  }

  return result;
};
