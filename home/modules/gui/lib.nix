{ lib }:
{
  materializeRuntimePaths =
    {
      files ? [ ],
      dirs ? [ ],
    }:
    ''
      materialize_file() {
        local target=$1
        local resolved=

        if [[ ! -e "$target" ]]; then
          return
        fi

        resolved="$(readlink -f "$target" || true)"
        if [[ -n "$resolved" && "$resolved" != "$target" && -f "$resolved" ]]; then
          rm -f "$target"
          install -Dm644 "$resolved" "$target"
        fi
      }

      materialize_dir() {
        local target=$1
        local resolved=

        if [[ ! -e "$target" ]]; then
          return
        fi

        resolved="$(readlink -f "$target" || true)"
        if [[ -n "$resolved" && "$resolved" != "$target" && -d "$resolved" ]]; then
          rm -rf "$target"
          mkdir -p "$(dirname "$target")"
          cp -aT "$resolved" "$target"
        fi
      }

      ${lib.optionalString (files != [ ]) ''
        for target in ${lib.escapeShellArgs files}; do
          materialize_file "$target"
        done
      ''}
      ${lib.optionalString (dirs != [ ]) ''
        for target in ${lib.escapeShellArgs dirs}; do
          materialize_dir "$target"
        done
      ''}
    '';
}
