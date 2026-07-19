#!/bin/bash

# CI/CD Pipeline Standard: Fail fast on errors/undefined vars/pipe failures.
set -euo pipefail

INITIAL_DIR=$(pwd)
SOURCES_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sources)
            SOURCES_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ -z "$SOURCES_DIR" ]; then
    echo "Usage: $0 --sources <directory>"
    exit 1
fi

# Convert to absolute path if it is relative
if [[ ! "$SOURCES_DIR" =~ ^/ ]]; then
    SOURCES_DIR="$INITIAL_DIR/$SOURCES_DIR"
fi

mkdir -p "$SOURCES_DIR"
cd "$SOURCES_DIR"

# Clone repositories if they don't exist
if [ ! -d "fortesreport-ce" ]; then
    echo "--> [INIT] Cloning fortesreport-ce..."
    git clone https://github.com/fortesinformatica/fortesreport-ce.git
fi

if [ ! -d "ACBr" ]; then
    echo "--> [INIT] Cloning ACBr..."
    git clone https://github.com/ProjetoACBr/ACBr.git
fi

if [ ! -d "PowerPDF" ]; then
    echo "--> [INIT] Cloning PowerPDF..."
    git clone https://github.com/drungrin/PowerPDF.git
fi

cd ACBr

# -----------------------------------------------------------------------------
# Source Normalization: {$R} resource case-sensitivity
# -----------------------------------------------------------------------------
# Upstream (Windows/Delphi) occasionally references a resource file with a case
# or path-separator that does not match the on-disk name, e.g.
#   {$R ..\ACBrNFSeXLogo.RES}   while the committed file is  ACBrNFSeXLogo.res
# Delphi/Windows is case-insensitive so it builds there, but our Lazarus/FPC
# build runs on a case-sensitive Linux filesystem and aborts with:
#   Error: (9031) Can't open resource file "...ACBrNFSeXLogo.RES"
# We scan the sources for {$R <file>} directives and, whenever the referenced
# name does not exist but a case-insensitive match does, create a symlink under
# the exact referenced name so the compiler resolves it. This is self-healing
# for future occurrences and survives the daily upstream merge (this script is
# ours, not synced from upstream).
echo "--> [INIT] Normalizando referencias de recursos ({\$R}) para filesystem case-sensitive..."
normalize_resource_refs() {
    # ACBr sources are ISO-8859/CRLF, which a UTF-8 locale flags as "binary";
    # force byte matching (LC_ALL=C) and treat as text (grep -a) so scanning works.
    # Files that carry a {$R <file>} directive (excluding wildcard forms like *.dfm/*.lfm)
    { LC_ALL=C grep -ralE '\{\$R[[:space:]]+[^*}]+\}' \
        --include='*.pas' --include='*.lpr' --include='*.dpr' --include='*.inc' . 2>/dev/null || true; } | \
    while IFS= read -r src; do
        srcdir=$(dirname "$src")
        LC_ALL=C grep -aoE '\{\$R[[:space:]]+[^*}]+\}' "$src" 2>/dev/null | \
            sed -E 's/^\{\$R[[:space:]]+//; s/[[:space:]]*\}[[:cntrl:]]*$//' | while IFS= read -r ref; do
            ref=${ref//\\//}                       # Windows path separators -> POSIX
            target="$srcdir/$ref"
            [ -e "$target" ] && continue           # already resolves on disk
            tdir=$(dirname "$target")
            tbase=$(basename "$target")
            [ -d "$tdir" ] || continue
            actual=$(find "$tdir" -maxdepth 1 -iname "$tbase" -print -quit 2>/dev/null)
            [ -n "$actual" ] || continue           # no case-insensitive match either
            ln -sf "$(basename "$actual")" "$target"
            echo "    [FIX] $src: criado '$tbase' -> '$(basename "$actual")'"
        done
    done
    return 0
}
normalize_resource_refs

CONST_IMAGE="drungrin/lazarus-builder:1.0.0"

# Inventory definition.
# Supports multi-project builds within the same repo checkout.
PROJECTS=(
  "Projetos/ACBrLib/Fontes/AbecsPinpad/ACBrLibAbecsPinpad.lpi"
  "Projetos/ACBrLib/Fontes/BAL/ACBrLibBAL.lpi"
  "Projetos/ACBrLib/Fontes/Boleto/ACBrLibBoleto.lpi"
  "Projetos/ACBrLib/Fontes/CEP/ACBrLibCEP.lpi"
  "Projetos/ACBrLib/Fontes/CHQ/ACBrLibCHQ.lpi"
  "Projetos/ACBrLib/Fontes/ConsultaCNPJ/ACBrLibConsultaCNPJ.lpi"
  "Projetos/ACBrLib/Fontes/CTe/ACBrLibCTe.lpi"
  "Projetos/ACBrLib/Fontes/CupomVerde/ACBrLibCupomVerde.lpi"
  "Projetos/ACBrLib/Fontes/DCe/ACBrLibDCe.lpi"
  "Projetos/ACBrLib/Fontes/eSocial/ACBrLibeSocial.lpi"
  "Projetos/ACBrLib/Fontes/ETQ/ACBrLibETQ.lpi"
  "Projetos/ACBrLib/Fontes/ExtratoAPI/ACBrLibExtratoAPI.lpi"
  "Projetos/ACBrLib/Fontes/GNRe/ACBrLibGNRe.lpi"
  "Projetos/ACBrLib/Fontes/GTIN/ACBrLibGTIN.lpi"
  "Projetos/ACBrLib/Fontes/IBGE/ACBrLibIBGE.lpi"
  "Projetos/ACBrLib/Fontes/LCB/ACBrLibLCB.lpi"
  "Projetos/ACBrLib/Fontes/Mail/ACBrLibMail.lpi"
  "Projetos/ACBrLib/Fontes/MDFe/ACBrLibMDFe.lpi"
  "Projetos/ACBrLib/Fontes/NCMs/ACBrLibNCMs.lpi"
  "Projetos/ACBrLib/Fontes/NF3e/ACBrLibNF3e.lpi"
  "Projetos/ACBrLib/Fontes/NFCom/ACBrLibNFCom.lpi"
  "Projetos/ACBrLib/Fontes/NFe/ACBrLibNFe.lpi"
  "Projetos/ACBrLib/Fontes/NFSe/ACBrLibNFSe.lpi"
  "Projetos/ACBrLib/Fontes/PIXCD/ACBrLibPIXCD.lpi"
  "Projetos/ACBrLib/Fontes/PosPrinter/ACBrLibPosPrinter.lpi"
  "Projetos/ACBrLib/Fontes/Reinf/ACBrLibReinf.lpi"
  "Projetos/ACBrLib/Fontes/SAT/ACBrLibSAT.lpi"
  "Projetos/ACBrLib/Fontes/Sedex/ACBrLibSedex.lpi"
  "Projetos/ACBrMonitorPLUS/Lazarus/ACBrMonitor.lpi"
)

# -----------------------------------------------------------------------------
# Runtime Dependency Injection
# -----------------------------------------------------------------------------
CMD_DEPENDENCIES="
    echo '--> [INIT] Registrando dependências...' && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrBaaS/ACBrBaaS.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrBoleto/ACBr_Boleto.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrBoleto/FC/Fortes/ACBr_BoletoFC_Fortes.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrBoleto/FC/FPDF/ACBr_BoletoFC_FPDF.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrBoleto/FC/Laz/ACBr_BoletoFC_LazReport.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrComum/ACBrComum.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrLibXML2/ACBrLibXML2.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDebitoAutomatico/ACBr_DebitoAutomatico.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrANe/ACBr_ANe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrBlocoX/ACBr_BlocoX.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrBPe/ACBr_BPe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrBPe/DABPE/EscPos/ACBr_BPeDabpeESCPOS.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrCIOT/ACBr_CIOT.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrCTe/ACBr_CTe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrCTe/DACTE/Fortes/ACBr_CTe_DACTeRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrDCe/ACBr_DCe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrDCe/DACE/Fortes/ACBr_DCe_DACERL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrDFeComum.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrDFeReportRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBreSocial/ACBre_Social.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrGNRE/ACBr_GNRE.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrGNRE/GNRE/Fortes/ACBr_GNREGuiaRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrGNRE/GNRE/Laz/ACBr_GNREGuiaLazReport.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrGTIN/ACBr_GTIN.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrMDFe/ACBr_MDFe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrMDFe/DAMDFE/Fortes/ACBr_MDFe_DAMDFeRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrMDFe/DAMDFE/FPDF/ACBr_MDFe_DAMDFeFPDF.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNF3e/ACBr_NF3e.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNF3e/DANF3e/EscPos/ACBr_NF3e_DANF3eESCPOS.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNF3e/DANF3e/Fortes/ACBr_NF3e_DANF3ERL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFCom/ACBr_NFCom.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFCom/DANFCom/Fortes/ACBr_NFCom_DANFComRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFe/ACBrECFVirtualNFCe/acbr_nfce_ecfvirtual.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFe/ACBr_NFe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFCe/EscPos/ACBr_NFe_DanfeESCPOS.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFe/Fortes/ACBr_NFe_DanfeRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFe/FPDF/ACBr_NFe_DanfeFPDF.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFe/Laz/ACBr_NFe_Danfe_LazReport.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFSe/ACBr_NFSe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFSe/DANFSE/Fortes/ACBr_NFSe_DanfseRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/ACBr_NFSeX.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/DANFSE/Fast/ACBr_NFSeXDanfseFR.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/DANFSE/Fortes/ACBr_NFSeXDanfseRL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/DANFSE/FPDF/ACBr_NFSeXDanfseFPDF.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrONE/ACBr_ONE.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrPAFNFCe/ACBr_PAFNFCe.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrReinf/ACBr_Reinf.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDFe/ACBrSATWS/ACBr_SATWS.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrDiversos/ACBrDiversos.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrIntegrador/ACBr_Integrador.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrOpenDelivery/ACBr_OpenDelivery.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrOpenSSL/ACBrOpenSSL.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrPagFor/ACBr_PagFor.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrPIXCD/ACBr_PIXCD.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrSAT/ACBrECFVirtualSAT/acbr_sat_ecfvirtual.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrSAT/ACBr_SAT.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrSAT/Extrato/EscPos/ACBr_SAT_Extrato_ESCPOS.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrSAT/Extrato/Fortes/ACBr_SAT_Extrato_Fortes.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrSAT/Extrato/FPDF/ACBr_SAT_Extrato_FPDF.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrSerial/ACBrSerial.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTCP/ACBr_MTER.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTCP/ACBrTCP.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTEFD/ACBr_TEFD.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrADRCST/ACBr_ADRCST.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrConvenio115/ACBr_Convenio115.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrDeSTDA/ACBR_DeSTDA.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrEDI/acbr_edi.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrLCDPR/ACBr_LCDPR.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrLFD/ACBr_LFD.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrOFX/acbr_ofx.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrPAF/ACBr_PAF.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrPonto/ACBr_Ponto.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrSEF2/ACBr_SEF2.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrSintegra/ACBr_Sintegra.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrSPED/ACBr_SPED.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/ACBrTXT/ACBrTXTComum.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/PCNComum/PCNComum.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link Pacotes/Lazarus/synapse/laz_synapse.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link /opt/fortesreport-ce/Packages/frce.lpk && \
    lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link /opt/PowerPDF/pack_powerpdf.lpk \
"

# -----------------------------------------------------------------------------
# Command Aggregation
# -----------------------------------------------------------------------------
# Strategy: Construct a monolithic command string to enforce a single container lifecycle.
# Avoiding "docker run" per project mitigates container cold-start latency.
EXECUTION_CHAIN="$CMD_DEPENDENCIES"

BUILD_MODES=(
    "Linux-x86_64-MT"
    "Linux-x86_64-ST"
    "Win64-x86_64-CDECL-MT"
    "Win64-x86_64-CDECL-ST"
    "Win64-x86_64-STDCALL-MT"
    "Win64-x86_64-STDCALL-ST"
    "Release-Linux-x86_64"
    "Release-Win64-x86_64"
)

for PROJ in "${PROJECTS[@]}"; do
    EXECUTION_CHAIN="${EXECUTION_CHAIN} && echo '--> [BUILD] Target: $PROJ' "

    LPI_FILE="$SOURCES_DIR/ACBr/$PROJ"

    if [ ! -f "$LPI_FILE" ]; then
        echo "[WARN] Project file not found: $LPI_FILE"
        continue
    fi

    for MODE in "${BUILD_MODES[@]}"; do
        # Check if build mode exists in .lpi file (XML)
        if grep -q "Name=\"$MODE\"" "$LPI_FILE"; then
            echo "[INFO] Adding build mode '$MODE' for $PROJ"
            EXECUTION_CHAIN="${EXECUTION_CHAIN} && lazbuild -B -r --lazarusdir=/usr/lib/lazarus --build-mode=\"$MODE\" $PROJ"
        fi
    done
done

# -----------------------------------------------------------------------------
# Pipeline Execution
# -----------------------------------------------------------------------------
echo "--- [PIPELINE] Initializing Build Container ---"

docker run --rm \
    -v "$SOURCES_DIR/ACBr":/app \
    -v "$SOURCES_DIR/fortesreport-ce":/opt/fortesreport-ce \
    -v "$SOURCES_DIR/PowerPDF":/opt/PowerPDF \
    -w /app \
    $CONST_IMAGE \
    /bin/bash -c "$EXECUTION_CHAIN"

# -----------------------------------------------------------------------------
# Artifact Consolidation
# -----------------------------------------------------------------------------
echo "--- [PIPELINE] Consolidating Artifacts ---"

mkdir -p "$SOURCES_DIR/Output"

# Dynamic artifact retrieval based on ACBr convention.
# Path resolution relies on standard "bin/" output structure defined in .lpi files.
for PROJ in "${PROJECTS[@]}"; do
    BASE_DIR=$(dirname "$PROJ")
    SEARCH_PATH="$SOURCES_DIR/ACBr/$BASE_DIR"

    if [ -d "$SEARCH_PATH/bin" ]; then
        echo "[INFO] Processing output for: $BASE_DIR"

        cd "$SEARCH_PATH/bin"
        find . -type f \( -name "*.so" -o -name "*.dll" \) -exec sh -c '
            dest_root="$1"
            shift
            for file do
                dest="$dest_root/${file#./}"
                mkdir -p "$(dirname "$dest")"
                cp -v "$file" "$dest"
            done
        ' sh "$SOURCES_DIR/Output" {} +
        cd - > /dev/null
    fi
done

# Hard coded artifacts for ACBrMonitorPLUS
echo "[INFO] Copying hard-coded artifacts for ACBrMonitorPLUS"
mkdir -p "$SOURCES_DIR/Output/Linux"
mkdir -p "$SOURCES_DIR/Output/Windows"

if [ -f "$SOURCES_DIR/ACBr/Projetos/ACBrMonitorPLUS/Lazarus/ACBrMonitor" ]; then
    cp -v "$SOURCES_DIR/ACBr/Projetos/ACBrMonitorPLUS/Lazarus/ACBrMonitor" "$SOURCES_DIR/Output/Linux/ACBrMonitor"
fi

if [ -f "$SOURCES_DIR/ACBr/Projetos/ACBrMonitorPLUS/Lazarus/ACBrMonitor64.exe" ]; then
    cp -v "$SOURCES_DIR/ACBr/Projetos/ACBrMonitorPLUS/Lazarus/ACBrMonitor64.exe" "$SOURCES_DIR/Output/Windows/ACBrMonitor64.exe"
fi


echo "--- [SUCCESS] Pipeline Finished ---"
echo "Artifacts are located in: $SOURCES_DIR/Output"
