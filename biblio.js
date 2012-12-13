var formatCitation = function(style, locale, item, format) {
  var sys = {};
  sys.retrieveItem = function(id) { return item };
  sys.retrieveLocale = function(id) { return locale };
  var citeProc = new CSL.Engine(sys, style);
  citeProc.updateItems(["item"]);
  citeProc.setOutputFormat(format);
  var bib = citeProc.makeBibliography();
  var result = "Not enough metadata to construct bibliographic item.";
  if (bib[0]["bibliography_errors"].length == 0) {
    result = bib[1][0];
  }
  return result;
}