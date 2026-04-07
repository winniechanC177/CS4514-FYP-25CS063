from datasets import load_dataset
import os

LANG_PAIRS = {
    "en-ja_JP": ("English", "Japanese"),
    "en-zh_CN": ("English", "Chinese"),
    "en-fr_FR": ("English", "French"),
    "en-hi_IN": ("English", "Hindi"),
    "en-es_MX": ("English", "Spanish"),
    "en-pt_br": ("English", "Portuguese"),
}

MAX_SAMPLES = 20
SKIP_FIRST  = True
DOMAINS     = None

OUTPUT_PATH = os.path.join(
    os.path.dirname(__file__), "..", "lib", "benchmark", "bleu_dataset.dart"
)


def _dart_string(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def _build_samples(config: str, display_src: str, display_tgt: str) -> list[dict]:
    print(f"  Loading {config} …")
    ds    = load_dataset("google/wmt24pp", config, trust_remote_code=True)
    split = ds["test"] if "test" in ds else list(ds.values())[0]

    samples = []
    for i, row in enumerate(split):
        if SKIP_FIRST and i == 0:
            continue
        if DOMAINS and row.get("domain") not in DOMAINS:
            continue
        src = row["source"].strip()
        ref = row["original_target"].strip()
        if src and ref:
            samples.append({"source": src, "reference": ref,
                             "lang": display_src, "conv_lang": display_tgt})
        if MAX_SAMPLES and len(samples) >= MAX_SAMPLES:
            break

    print(f"    → {len(samples)} samples")
    return samples


def _render_dart(all_samples: dict[str, list[dict]]) -> str:
    lines = [
        "class TranslationSample {",
        "  final String source;",
        "  final String language;",
        "  final String convLanguage;",
        "  final List<String> references;",
        "",
        "  const TranslationSample({",
        "    required this.source,",
        "    required this.language,",
        "    required this.convLanguage,",
        "    required this.references,",
        "  });",
        "}",
        "",
    ]

    dataset_var_names = []

    for config, samples in all_samples.items():
        src_lang, tgt_lang = config.split("-")
        var_name = f"{src_lang}To{tgt_lang.capitalize()}Dataset"
        dataset_var_names.append(var_name)

        lines.append(f"const List<TranslationSample> {var_name} = [")
        for s in samples:
            src_esc = _dart_string(s["source"])
            ref_esc = _dart_string(s["reference"])
            lines.append(
                f"  TranslationSample("
                f"source: '{src_esc}', "
                f"language: '{s['lang']}', "
                f"convLanguage: '{s['conv_lang']}', "
                f"references: ['{ref_esc}']),",
            )
        lines.append("];")
        lines.append("")

    lines.append("const List<TranslationSample> allDatasets = [")
    for v in dataset_var_names:
        lines.append(f"  ...{v},")
    lines.append("];")
    lines.append("")

    return "\n".join(lines)


def main():
    print("Loading google/wmt24pp …")
    all_samples: dict[str, list[dict]] = {}

    for config, (display_src, display_tgt) in LANG_PAIRS.items():
        try:
            all_samples[config] = _build_samples(config, display_src, display_tgt)
        except Exception as e:
            print(f"  ✗ Failed to load {config}: {e}")

    dart_code = _render_dart(all_samples)

    out = os.path.abspath(OUTPUT_PATH)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(dart_code)

    print(f"\n✓ Written to {out}")
    total = sum(len(v) for v in all_samples.values())
    print(f"  {total} samples across {len(all_samples)} language pairs.")


if __name__ == "__main__":
    main()
