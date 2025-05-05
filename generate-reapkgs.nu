#!/usr/bin/env nu

def sanitize_name [name: string] {
    $name | 
    iconv -f utf8 -t ascii//TRANSLIT |
    str replace -a '%20' ' ' |
    str replace -a '+' 'plus' |
    str replace -ar '[^[:alnum:]-]' '-' |
    str replace -ar '-{2,}' '-' |
    str replace -ar '^-' '' |
    str replace -ar '-$' '' |
    str replace -ar '^[^a-zA-Z]' '_$0' |
    str downcase
}

def get_attrset_from_index [xml_content: string] {
    let parsed_xml = ($xml_content | from xml)
    let index_name = $parsed_xml.index.@name

    let packages = ($parsed_xml.index.category | 
        flatten | 
        where reapack != null | 
        flatten | 
        each { |category|
            $category.reapack | 
            each { |reapack|
                $reapack.version | 
                each { |version|
                    {
                        name: $reapack.@name
                        category: $category.@name
                        type: $reapack.@type
                        version: $version.@name
                        sources: ($version.source | 
                            each { |source|
                                $"($source.#text),($source.@file);"
                            } | 
                            str join ''
                        )
                    }
                }
            }
        } | 
        flatten | 
        each { |pkg|
            $"($pkg.name)|($pkg.category)|($pkg.type)|($pkg.version)|($pkg.sources)"
        }
    )
    
    let processed_packages = {}
    
    $packages | lines | each { |line|
        let parts = ($line | split row '|')
        let package_name = $parts.0
        let category_name = $parts.1
        let package_type = $parts.2
        let version = $parts.3
        let sources = ($parts.4 | split row ';' | each { |source|
            let source_parts = ($source | split row ',')
            {
                url: $source_parts.0
                path: $source_parts.1
                sha256: ""
            }
        })
        
        let full_package_name = (sanitize_name $"($package_name)-($version)")
        
        let suffix = if ($processed_packages | get -i $full_package_name) != null {
            let counter = ($processed_packages | get $full_package_name) + 1
            $processed_packages = ($processed_packages | upsert $full_package_name $counter)
            $"_($counter)"
        } else {
            $processed_packages = ($processed_packages | insert $full_package_name 1)
            ""
        }
        
        let full_package_name_with_suffix = $"($full_package_name)($suffix)"
        
        let sources_str = ($sources | each { |s|
            $"        {
          path = ''${($s.path)}'';
          url = \"($s.url)\";
          sha256 = \"\";
        }"
        } | str join "\n")
        
        $"    ($full_package_name_with_suffix) = mkReapackPackage {
      inherit lib stdenv fetchurl;
      name = \"($full_package_name_with_suffix)\";
      indexName = \"($index_name)\";
      categoryName = \"($category_name)\";
      packageType = \"($package_type)\";
      sources = [
($sources_str)
      ];
    };"
    } | str join "\n"
}

def generate_nix_from_index [dir: string, index_url: string] {
    let xml_content = (http get $index_url)
    let parsed_xml = ($xml_content | from xml)
    let index_name = ($parsed_xml.index.@name | sanitize_name)
    let output_file = $"($dir)/($index_name).nix"
    
    let content = $"{{
  lib,
  mkReapackPackage, 
  stdenv, 
  fetchurl,
}}: {{
  ($index_name) = {{
(get_attrset_from_index $xml_content)
  }};
}}"
    
    $content | save -f $output_file
}

def replace_hash [file: string, url: string, sha256: string] {
    open $file | 
    str replace -ar $"(?ms)(url = \"($url)\";\\s*sha256 = \")[^\"]*" $"$1($sha256)" |
    save -f $file
}

def prefetch_hash [file: string, url: string] {
    let name = (sanitize_name (basename $url))
    let redirected_url = (http get $url --headers-only | get headers.location | default $url)
    let sha256 = (do -i { nix-prefetch-url $redirected_url --name $name } | complete)
    
    if $sha256.exit_code == 0 {
        $"($file)|($url)|($sha256.stdout | str trim)"
    } else {
        error make {msg: $"Error prefetching ($redirected_url) (redirected from ($url))"}
    }
}

def print_help [] {
    let name = "nix run github:silvarc141/reapkgs --"
    print $"Usage: ($name) [options]
Options:
  -h              Display this help message
  -g              Generate indexes and related files
  -p              Prefetch hashes for package sources
  -r              Replace hashes in generated files
  -o <directory>  Set output directory for generated files (if empty, use ./generated)
  -i <file>       Specify a file containing newline-separated index URLs (if empty, use known repos)
  -d <file>       Specify a file to store and read hash data (if empty, use temp file)
  -j <processes>  Specify the number of processes to use for prefetching
  -q              Do not create log files
Examples:
  ($name) -gpr                        # Create reapkgs flake for known repos' indexes
  ($name) -gpr -i ./index-list.txt    # Create reapkgs flake for a custom index url list
  ($name) -p -d ./new-hashes.txt      # Prefetch hash data of urls in nix files in default ./generated path to ./new-hashes.txt
  ($name) -r -d ./old-hashes.txt      # Replace hashes in default ./generated path using hash data from ./old-hashes.txt
  ($name) -p -j 4                     # Prefetch hash data using 4 cores"
}

# Main script logic
let args = (
    $env.args | 
    parse "{-h} {-g} {-p} {-r} {-o:string} {-i:string} {-d:string} {-j:string} {-q}"
)

if ($args | length) == 0 {
    print_help
    exit 0
}

let generate = $args.-g
let prefetch_hashes = $args.-p
let replace_hashes = $args.-r
let output_directory = ($args.-o | default "./generated")
let index_urls_path = $args.-i
let hash_data_path = $args.-d
let processes = $args.-j
let no_logs = $args.-q

if $args.-h {
    print_help
    exit 0
}

let index_output_subdir = $"($output_directory)/reapack-packages"

let index_urls = if $index_urls_path != null {
    open $index_urls_path | lines
} else {
    http get "https://reapack.com/repos.txt" | lines
}

if ($index_urls | length) == 0 {
    print "No urls passed, using known repos' indexes"
    let index_urls = (http get "https://reapack.com/repos.txt" | lines)
}

if $generate or $prefetch_hashes {
    mkdir $output_directory
    mkdir $index_output_subdir
}

if $generate {
    print "Generating nix from indexes..."
    let total_indexes = ($index_urls | length)
    
    for index_url in $index_urls {
        let current_index = ($index_urls | index-of $index_url) + 1
        print $"Processing index ($current_index) of ($total_indexes): ($index_url)"
        generate_nix_from_index $index_output_subdir $index_url
    }
    
    print "Generating default.nix..."
    let files = (
        ls $"($index_output_subdir)/*.nix" | 
        where name !~ "default.nix" | 
        get name | 
        each { |f| $"./(basename $f)" } | 
        sort | 
        each { |f| $"    ($f)" } | 
        str join "\n"
    )
    
    open ./template-default.nix | 
    str replace ".*#insert.*" $files | 
    save -f $"($index_output_subdir)/default.nix"
    
    print "Generating flake.nix..."
    let urls = (
        $index_urls | 
        sort | 
        each { |u| $"    ($u)" } | 
        str join "\n"
    )
    
    open ./template-flake.nix | 
    str replace ".*#insert.*" $urls | 
    save -f $"($output_directory)/flake.nix"
    
    print "Copying mk-reapack-package.nix..."
    cp ./mk-reapack-package.nix $output_directory
}

if $prefetch_hashes {
    print "Prefetching hashes..."
    let hash_data = (
        ls $"($index_output_subdir)/*.nix" | 
        where name !~ "default.nix" | 
        each { |file| 
            open $file.name | 
            lines | 
            where $it =~ 'url = ' | 
            str replace -r '.*url = "(.*)".*' '$1' | 
            each { |url| {file: $file.name, url: $url} }
        } | 
        flatten | 
        each { |item| 
            do -i { prefetch_hash $item.file $item.url }
        } | 
        where $it != null
    )
    
    $hash_data | save -f ($hash_data_path | default "hash.tmp")
}

if $replace_hashes {
    print "Replacing hashes in files..."
    let hash_data = (open ($hash_data_path | default "hash.tmp") | lines)
    
    for line in $hash_data {
        let parts = ($line | split row '|')
        let file = $parts.0
        let url = $parts.1
        let sha256 = $parts.2
        
        if (do -i { replace_hash $file $url $sha256 }).exit_code != 0 {
            print $"Failed to replace hash for ($url) in ($file)"
        }
    }
}

if $prefetch_hashes and $replace_hashes and ($hash_data_path | empty?) {
    print "Cleaning up temporary hash file..."
    rm hash.tmp
}
