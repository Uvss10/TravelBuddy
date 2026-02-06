import subprocess

def call_llm(prompt: str, model: str = "llama3") -> str:
    """
    Calls local Ollama LLM and returns raw text output
    """
    result = subprocess.run(
        ["ollama", "run", model],
        input=prompt,
        text=True,
        capture_output=True
    )

    return result.stdout.strip()
