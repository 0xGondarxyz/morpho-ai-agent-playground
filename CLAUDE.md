# Project Instructions

## Markdown Formatting Rules

When generating markdown files:

1. **Never nest code blocks** - Don't wrap examples in triple-backtick markdown blocks
2. **Use 4-space indentation for examples** - This renders as a code block without nesting issues
3. **Mermaid diagrams** - Write directly with triple-backtick mermaid, not inside another code block

Correct example format:

    # Title

    Some text

    ```mermaid
    graph TD
        A --> B
    ```

## KB Structure

```
kb/
├── system-digest.md      # Single-page protocol overview
├── starterPrompts.md     # Prompt to regenerate KB on new codebases
└── charts/
    ├── setup.md          # Deployment & configuration diagrams
    ├── roles.md          # Access control matrix & hierarchy
    └── usage-flows.md    # User journey sequence diagrams
```
