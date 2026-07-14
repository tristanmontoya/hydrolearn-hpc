#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${repo_root}"

if ! command -v pandoc >/dev/null 2>&1; then
    echo "pandoc is required to render assignment HTML" >&2
    exit 1
fi

template_file="$(mktemp)"
trap 'rm -f "${template_file}"' EXIT

# Use a HydroLearn-ready HTML fragment
cat > "${template_file}" <<'TEMPLATE'
<style>
  .code-box {
    background: #f5f5f5;
    max-width: 80ch;
    white-space: pre-wrap;
    overflow-wrap: break-word;
  }

  .directive-table {
    border-collapse: collapse;
    width: 100%;
    margin: 1em 0;
  }

  .directive-table th,
  .directive-table td {
    border: 1px solid #ddd;
    padding: 0.5em 0.75em;
    text-align: left;
    vertical-align: top;
  }

  .directive-table th {
    background: #f5f5f5;
  }

  .directive-table code {
    white-space: nowrap;
  }
</style>
$body$
TEMPLATE

render_assignment() {
    local page_title="$1"
    local input_path="$2"
    local output_path="$3"

    mkdir -p "$(dirname "${output_path}")"

    pandoc \
        --from=gfm+tex_math_dollars \
        --to=html5 \
        --mathjax \
        --standalone \
        --syntax-highlighting=none \
        --wrap=none \
        --template="${template_file}" \
        --metadata pagetitle="${page_title}" \
        "${input_path}" \
        --output "${output_path}"
}

render_assignment \
    "1.5.1 Activity Overview" \
    "ASSIGNMENT.md" \
    "_html/ASSIGNMENT.html"

render_assignment \
    "Scenario 1: Parallel Execution of a Distributed Hydrologic Model" \
    "bow_at_banff_distributed_execution/ASSIGNMENT.md" \
    "_html/bow_at_banff_distributed_execution/ASSIGNMENT.html"

render_assignment \
    "Scenario 2: Parallel Calibration of a Lumped Hydrologic Model" \
    "bow_at_banff_lumped_calibration/ASSIGNMENT.md" \
    "_html/bow_at_banff_lumped_calibration/ASSIGNMENT.html"

# Keep generated HTML minimal and strip local links between assignment parts
perl -pi -e '
    s{<a href="..\/ASSIGNMENT\.md">([^<]*)</a>}{$1}g;
    s{<a href="(bow_at_banff_[^"]*\/ASSIGNMENT)\.md">([^<]*)</a>}{$2}g;
    s/<h([1-6]) id="[^"]*">/<h$1>/g;
    s{<(\/?)h([1-5])>}{"<$1h" . ($2 + 1) . ">"}eg;
    s{^<h2>.*</h2>\n?}{};
    s/<pre(?: class="[^"]+")?>/<pre class="code-box">/g;
    s/<table>/<table class="directive-table">/g;
    s/<ol type="1">/<ol>/g;
    s/ style="text-align: right;"//g;
    s/&quot;/"/g;
' \
    "_html/ASSIGNMENT.html" \
    "_html/bow_at_banff_distributed_execution/ASSIGNMENT.html" \
    "_html/bow_at_banff_lumped_calibration/ASSIGNMENT.html"

# Keep generated math as plain escaped LaTeX delimiters
perl -0pi -e '
    s{<span class="math inline">(.*?)</span>}{$1}gs;
    s{<span class="math display">(.*?)</span>}{$1}gs;
' \
    "_html/ASSIGNMENT.html" \
    "_html/bow_at_banff_distributed_execution/ASSIGNMENT.html" \
    "_html/bow_at_banff_lumped_calibration/ASSIGNMENT.html"

# Adjust nested HTML image links to HydroLearn Studio asset paths
perl -pi -e '
    s{src="..\/figures\/([^"]+)"}{src="/asset-v1:CIROH_HydroLearn+HPC201+2026+type\@asset+block\@$1"}g;
' \
    "_html/bow_at_banff_distributed_execution/ASSIGNMENT.html" \
    "_html/bow_at_banff_lumped_calibration/ASSIGNMENT.html"

# Format assignment figures with numbered captions
perl -0pi -e '
    my %captions = (
        "workflow_parallel_execution.png" => [
            "Figure 6.",
            "Distributed modeling workflow.",
        ],
        "calibration_lumped.png" => [
            "Figure 7.",
            "Serial lumped calibration workflow.",
        ],
        "calibration_batch_lumped.png" => [
            "Figure 8.",
            "Parallel lumped calibration workflow.",
        ],
    );
    my $figure_style = q{text-align: center;};
    my $image_style = q{width: 70%; height: auto;};
    my $caption_style = q{margin: 0.75em 0 1.5em 0;};
    s{<p><img src="([^"]*/([^"/]+))" alt="([^"]+)" /></p>}{
        my $src = $1;
        my $filename = $2;
        my $alt = $3;
        $filename =~ s/^asset-v1:.*block@//;
        if (exists $captions{$filename}) {
            my ($number, $title) = @{$captions{$filename}};
            qq{<figure style="$figure_style"><img src="$src" alt="$alt" style="$image_style" />\n}
                . qq{<figcaption style="$caption_style"><strong>$number</strong> $title</figcaption>\n}
                . qq{</figure>};
        } else {
            $&
        }
    }eg;
' \
    "_html/ASSIGNMENT.html" \
    "_html/bow_at_banff_distributed_execution/ASSIGNMENT.html" \
    "_html/bow_at_banff_lumped_calibration/ASSIGNMENT.html"
