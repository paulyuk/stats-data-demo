# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set environment variables
ENV POETRY_VERSION=1.8.4

# Install Poetry
RUN pip install "poetry==$POETRY_VERSION"

# Set the working directory in the container
WORKDIR /app

# Copy the pyproject.toml and poetry.lock files to the container
COPY pyproject.toml poetry.lock ./

# Install the dependencies
RUN poetry install --no-dev

# Copy the rest of the application code to the container
COPY . .

# Set the entry point for the container
CMD ["poetry", "run", "uvicorn", "baseball_agent:app"]