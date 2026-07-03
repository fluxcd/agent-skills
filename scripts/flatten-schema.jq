# Flatten a CRD OpenAPI schema into a greppable field index for AI agents.
# Emits one line per field so a dotted-path grep replaces reading the full JSON schema:
#   <dotted.path> <type> [(required)] [enum=a|b] [default=x] <TAB> # description
# Arrays are path[]; string maps are <map[string]T>; free-form/untyped values are <any>.
#
# Usage (see the flatten-schemas target in the Makefile):
#   jq -r --arg src <schema.json> -f scripts/flatten-schema.jq <schema.json> > <index.txt>

# The schema JSONs carry no group-version-kind metadata, so the emitted
# apiVersion/kind lines are derived: kind from the root description's first word,
# version from the filename, and the API group from the filename's shortname below.
# ArtifactGenerator is special-cased: its "source" shortname belongs to
# source.extensions.fluxcd.io (source-watcher), not source.toolkit.fluxcd.io.
def groups: {
  fluxcd: "fluxcd.controlplane.io",
  source: "source.toolkit.fluxcd.io",
  kustomize: "kustomize.toolkit.fluxcd.io",
  helm: "helm.toolkit.fluxcd.io",
  notification: "notification.toolkit.fluxcd.io",
  image: "image.toolkit.fluxcd.io"
};

def clean: gsub("[\n\t]+"; " ") | gsub(" +"; " ");

def typestr:
  if .["x-kubernetes-int-or-string"] == true then "<int-or-string>"
  elif .type == "array" then
    (.items // {}) as $i
    | if $i.type != null and $i.type != "object" then "<[]\($i.type)>" else "<[]object>" end
  elif .type == "object" and (.additionalProperties | type == "object") and (.additionalProperties.type != null) then
    "<map[string]\(.additionalProperties.type)>"
  elif .type == "object" and (.properties == null) then "<object (free-form)>"
  elif .type != null then "<\(.type)>"
  else "<any>" end;

def annotations:
  ( if .enum then " enum=" + (.enum | map(tostring) | join("|")) else "" end )
  + ( if has("default") then " default=" + (.default | tojson) else "" end );

def line($path; $req):
  $path + " " + typestr
  + (if $req then " (required)" else "" end)
  + annotations
  + ((.description // "") | clean | if . == "" then "" else "\t# " + . end);

def emit($prefix):
  (.required // []) as $req
  | (.properties // {}) | to_entries[]
  | .key as $k | .value as $v
  | ($prefix + $k) as $p
  | ($v | line($p; ($req | index($k)) != null)),
    ( if $v.type == "array" and ($v.items.properties != null) then
        ($v.items | emit($p + "[]."))
      elif $v.properties != null then
        ($v | emit($p + "."))
      elif $v.type == "object" and ($v.additionalProperties | type == "object") and ($v.additionalProperties.properties != null) then
        ($v.additionalProperties | emit($p + ".<key>."))
      else empty end );

($src | sub("\\.json$"; "") | split("-")) as $parts
| ((.description // "") | split(" ")[0]) as $kind
| (if $kind == "ArtifactGenerator" then "source.extensions.fluxcd.io"
   else (groups[$parts[-2]] // error("unknown API group shortname: " + $parts[-2])) end) as $group
| "apiVersion <string> enum=\($group)/\($parts[-1])",
  "kind <string> enum=\($kind)",
  # All Flux CRDs are namespaced; generic metadata lines replace the schema's
  # free-form metadata boilerplate.
  "metadata.name <string> (required)",
  "metadata.namespace <string> (required)",
  (del(.properties.apiVersion, .properties.kind, .properties.metadata) | emit(""))
