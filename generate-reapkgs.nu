#!/usr/bin/env -S nu --stdin

let MAX_THREADS = 32 

let TYPE_TO_PATH = {
  script: "Scripts",
  effect: "Effects",
  data: "Data",
  extension: "UserPlugins",
  theme: "ColorThemes",
  langpack: "LangPack",
  "webinterface": "reaper_www_root",
  "project-template": "ProjectTemplates",
  "track-template": "TrackTemplates",
  "midi-note-names": "MIDINoteNames",
  "automation-item": "AutomationItems"
}

def prefetch-file-item [] {
  let item = $in
  let url = $item.url

  let redirected_url = curl -w "%{url_effective}" -I -L -s -S -o /dev/null $url | str trim
  let sanitized_name = $url | url parse | get path | path basename | url decode | str replace -r -a '[^-.+_?=0-9a-zA-Z]' '-'

  let prefetch_result = nix-prefetch-url $redirected_url --name $sanitized_name | complete

  mut output = ""

  if ($prefetch_result.exit_code != 0 or $prefetch_result.stdout == "") {
    print -e $"Error prefetching ($redirected_url)"
  } else {
    $output = $prefetch_result.stdout | str trim
  }

  $item | merge {
    redirected_url: $redirected_url,
    sha256: $output
  }
}

def generate-flat-worklist [ ] {
  let raw_index = http get $in
  let index_name = $raw_index.attributes.name

  $raw_index.content | each { |raw_category|
    let category_name = $raw_category | get -o attributes.name

    $raw_category.content | each { |raw_package|
      let package_name = $raw_package | get -o attributes.name
      let package_type = $raw_package | get -o attributes.type
      let package_description = $raw_package | get -o attributes.desc

      $raw_package | get content | where tag == version | each { |raw_version|
        let version_name = $raw_version | get -o attributes.name
        let version_time = ($raw_version | get attributes.time | into datetime)
        let version_author = $raw_version | get -o attributes.author

        $raw_version | get content | where tag == source | each { |raw_source|
          let raw_explicit_path = $raw_source | get -o attributes.file
          let url = $raw_source | get -o content.content.0

          let relative_path = if $raw_explicit_path == null {
            $url | path basename | url decode
          } else {
            $raw_explicit_path
          }

          let parent_dir = if $package_type in ["script", "effect", "automation-item"] {
            $"($TYPE_TO_PATH | get $package_type)/($index_name)/($category_name)"
          } else {
            $TYPE_TO_PATH | get $package_type
          }

          {
            category: $category_name,
            package_name: $package_name,
            package_type: $package_type,
            package_description: $package_description,
            version_name: $version_name,
            version_time: $version_time,
            version_author: $version_author,
            path: ($parent_dir | path join $relative_path),
            url: $url
          }
        }
      }
    }
  } | flatten | flatten | flatten
}

def create-structure [ ] {
  $in 
  | group-by category | transpose category packages
  | each { |category_row|
    $category_row.packages
    | group-by package_name | transpose package_name versions
    | each { |package_row|
      let sorted_versions = ($package_row.versions
        | group-by version_name | transpose version_name files
        | each { |version_row|
          let version_meta = ($version_row.files | first)

          {
            version_name: $version_row.version_name,
            time: $version_meta.version_time,
            files: ($version_row.files | select path url sha256)
          }
        }
        | sort-by --reverse time
        | reject time
      )

      {
        key: $package_row.package_name,
        val: ($sorted_versions
          | each { |v| { key: $v.version_name, val: $v.files } } 
          | prepend { key: "latest", val: ($sorted_versions | first).files }
          | transpose -r -d
        )
      }
    }
  } 
  | flatten 
  | transpose -r -d 
}

def main [ index_url ] {
  $index_url 
  | generate-flat-worklist
  | par-each --threads $MAX_THREADS { |item| prefetch-file-item }
  | create-structure
  | to json
}
