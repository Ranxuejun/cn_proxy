require_relative "../lib/crossref_latest"

$cache = CrossrefLatestCache.new
$cache.populate
