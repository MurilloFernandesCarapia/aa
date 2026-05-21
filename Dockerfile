# =====================================================================
# PetCare360 API - Dockerfile multi-stage
# =====================================================================
# Estagio 1: BUILD - compila o projeto usando o SDK completo do .NET 10.
# Estagio 2: RUNTIME - imagem final enxuta com apenas o necessario p/ rodar.
# Roda como usuario nao-root (appuser) -> atende exigencia do Challenge.
# =====================================================================

# ---------- Estagio 1: BUILD ----------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copia apenas o .csproj primeiro para aproveitar cache de layers do Docker.
# Se o .csproj nao mudou, o `dotnet restore` nao re-executa (build muito mais rapido).
COPY ["PetCare360.API/PetCare360.API.csproj", "PetCare360.API/"]
RUN dotnet restore "PetCare360.API/PetCare360.API.csproj"

# Agora copia todo o resto do codigo e publica em modo Release.
COPY . .
WORKDIR "/src/PetCare360.API"
RUN dotnet publish "PetCare360.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

# ---------- Estagio 2: RUNTIME ----------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Cria um grupo e usuario nao-root chamado 'appuser'.
# Nao fixamos UID/GID para evitar conflito com usuarios pre-existentes
# na imagem base (Debian 12 ja tem um 'app' no GID 1000).
RUN groupadd --system appuser && \
    useradd --system --gid appuser --create-home --shell /sbin/nologin appuser

# Copia o resultado do publish do estagio anterior.
COPY --from=build /app/publish .

# Ajusta permissoes para o usuario nao-root conseguir ler/escrever no app.
RUN chown -R appuser:appuser /app

# Variaveis de ambiente padrao do ASP.NET Core.
# Forca o Kestrel a escutar em 0.0.0.0:8080 (necessario p/ acesso externo via Docker).
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Troca para o usuario nao-root ANTES do ENTRYPOINT.
USER appuser

EXPOSE 8080

ENTRYPOINT ["dotnet", "PetCare360.API.dll"]
