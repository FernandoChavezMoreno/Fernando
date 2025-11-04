%% ============================================================
%  Limpieza única (Limpieza de Biodatos 1° Fase General)
%  - Carga "IDJE Fase.csv"
%  - Quita nulos -> conOutlayers; z-score fila (|z|>3) -> sinOutlayers
%  - Normaliza (Z-score manual, sin toolbox)
%  - Suaviza (Moving Mean, ventana=5)
% ============================================================
%% === CONFIGURACIÓN ===
filename   = 'FerFinal.csv';
canales_validos = ["AF3","AF4","F3","F4","F7","F8","FC5","FC6","O1","O2","P7","P8","T7","T8"];

fname_con  = 'FerFinal Fase_conOutlayers.csv';
fname_sin  = 'FerFinal Fase_sinOutlayers.csv';
fname_norm = 'FerFinal Fase_cleanNorm.csv';
fname_smoo = 'FerFinal Fase_cleanSmoot.csv';

%% === CARGA ===
T = readtable(filename, 'VariableNamingRule','preserve');
fprintf('\n[1/5] CSV cargado: %s | Columnas=%d | Filas=%d\n', filename, width(T), height(T));

%% === SELECCIÓN DE CANALES ===
colnamesAll = T.Properties.VariableNames;
keep = false(size(colnamesAll));
for i = 1:numel(colnamesAll)
    partes = strsplit(colnamesAll{i}, '/'); base = strtrim(partes{1});
    if any(strcmp(base, canales_validos)), keep(i) = true; end
end
T_channels = T(:, keep);
fprintf('[2/5] Seleccionados %d canales válidos.\n', width(T_channels));

%% === QUITAR NULOS (y mantener filas alineadas) ===
% Máscara de filas SIN nulos en los canales EEG
idx_after_missing = ~any(ismissing(T_channels), 2);

T_con = T_channels(idx_after_missing, :);
fprintf('[3/5] Tras quitar NULOS: Filas=%d | Nulos=%d\n', height(T_con), nnz(ismissing(T_con)));

% Exporta con columnas fijas alineadas por la MISMA máscara
%writetable([T(idx_after_missing,1:4)  T_con], fname_con);
writetable([T(idx_after_missing,1:3)  T_con], fname_con);

%% === QUITAR OUTLIERS (|z|>3) sobre T_con ===
X  = table2array(varfun(@double, T_con));
mu = mean(X,1,'omitnan');
sd = std(X,0,1,'omitnan'); sd(sd==0 | isnan(sd)) = 1;
Z  = (X - mu) ./ sd;

rowsOK_local = all(abs(Z) <= 3 | isnan(Z), 2);  % índice relativo a T_con
nOut         = sum(~rowsOK_local);
T_sin        = T_con(rowsOK_local, :);

% Levantar el índice a coordenadas de T (global)
idx_after_outliers = false(height(T),1);
idx_after_outliers(idx_after_missing) = rowsOK_local;

fprintf('[4/5] Outliers detectados (|z|>3): %d | Filas finales=%d\n', nOut, height(T_sin));
%writetable([T(idx_after_outliers,1:4)  T_sin], fname_sin);
writetable([T(idx_after_outliers,1:3) T_sin], fname_sin);
%% === NORMALIZAR y SUAVIZAR (solo numéricas), conservando columnas fijas ===
T_norm = T_sin;
numVars = varfun(@isnumeric, T_norm, 'OutputFormat','uniform');

% z-score manual
for j = find(numVars)
    v = T_norm{:,j};
    mu = mean(v,'omitnan'); sd = std(v,0,'omitnan'); if sd==0 || isnan(sd), sd=1; end
    T_norm{:,j} = (v - mu) / sd;
end

% movmean ventana=5
T_smoo = T_norm;
for j = find(numVars)
    T_smoo{:,j} = movmean(T_norm{:,j}, 5, 'omitnan');
end

writetable([T(idx_after_outliers,1:3)  T_norm], fname_norm);
writetable([T(idx_after_outliers,1:3)  T_smoo], fname_smoo);

%% === RESUMEN FINAL ===
Filas_antes         = height(T);
Nulos_totales_antes = nnz(ismissing(T));
Filas_sinNulos      = sum(idx_after_missing);
Nulos_restantes     = 0;
Filas_finales       = sum(idx_after_outliers);
Outliers_removidos  = Filas_sinNulos - Filas_finales;

fprintf('\n[5/5] RESUMEN:\n');
disp(table(Filas_antes, Nulos_totales_antes, Filas_sinNulos, ...
           Nulos_restantes, Outliers_removidos, Filas_finales));