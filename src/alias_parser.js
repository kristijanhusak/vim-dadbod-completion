module.exports = (content, tables = []) => {
  const result = {};
  if (!tables.length || !content.length) {
    return result;
  }
  const tableStr = `"?(${tables.join('|')})"?`
  const regex = new RegExp(`${tableStr}\\s+as\\s+(\\w+)`, 'g')
  let matches = true
  while (matches) {
    matches = regex.exec(content);
    if (matches) {
      result[matches[1]] = matches[2]
    }
  }

  return result;
};
