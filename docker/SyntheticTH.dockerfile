# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

# Copy the project file and restore dependencies
COPY src/SyntheticTH/SyntheticTH.csproj src/SyntheticTH/
RUN dotnet restore src/SyntheticTH/SyntheticTH.csproj

# Copy the source code and build
COPY src/SyntheticTH/ src/SyntheticTH/
WORKDIR /source/src/SyntheticTH
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Copy the published application
COPY --from=build /app/publish .

# The config.toml file should be mounted at runtime or built with environment-specific values
# Example: docker run -v /path/to/config.toml:/app/config.toml synthetic-th

# Set environment variables for .NET (optional)
ENV DOTNET_ENVIRONMENT=Production

# Run the worker service
ENTRYPOINT ["dotnet", "SyntheticTH.dll"]
