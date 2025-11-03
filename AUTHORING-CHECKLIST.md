# Authoring Checklist for System Design Cases

Use this checklist for every new case (ByteByteGo/Educative-style, concise, architecture most detailed):

- Folder structure: `case-studies/<NN>-<case-name>/`
  - `README.md` with Quick Navigation and style/references block
  - `01-requirements.md` (scale math, constraints, success measures)
  - `02-architecture.md` (most detailed; include Mermaid and data flows)
  - `03-key-decisions.md` (3–8 crisp trade-offs)
  - `04-wrap-up.md` (scaling, failures, monitoring, pitfalls, interview Q&A)
  - `diagrams/architecture.mmd` (Mermaid diagram saved separately)

- Diagrams
  - Prefer Excalidraw (whiteboard style). Store source at `diagrams/architecture.excalidraw` (or `.excalidraw.json`)
  - Optionally include Mermaid `diagrams/architecture.mmd` for code-friendly diffs
  - Export SVG/PNG next to the source when publishing (`architecture.svg`, `architecture.png`)
  - Link from the case README to the diagram(s). See `docs/diagram-style-guide.md`

- Writing style
  - Original wording; do not copy verbatim from sources
  - Cite ideas via repository `REFERENCES.md`
  - Diagram-first, “what/why”, minimal internals; total 5–7K words per case

- Quality gates
  - Links resolve; filenames consistent
  - No TODOs left in text; headings clean
  - Keep per-case terms city/domain-specific where needed
