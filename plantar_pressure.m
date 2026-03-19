clear
clc
close all
rng (42)
%% PARAMETERS
N_INJURED = 10;
N_HEALTHY = 10;
N_TRIALS = 3;

regions = {'Hallux','Toes','1st Metatarsal','2nd Metatarsal'...
    '3rd Metatarsal','4th-5th Metatarsal','Midfoot'...
    'Medial Heel','Lateral Heel'};
nRegions = numel(regions);
%% PRESSURE PROFILES
healthy_mu = [280, 220, 310, 340, 290, 200, 80, 30, 25];
healthy_sd = [40, 35, 45, 50, 42, 38, 20, 12, 10];

injured_mu = [380, 250, 430, 460, 360, 195, 95, 38, 22];
injured_sd = [60, 45, 70, 75, 58, 40, 28, 15, 12];

%% SIMULATE DATA
nTotalRows = (N_INJURED + N_HEALTHY) * N_TRIALS * 2;

ParticipantID = strings(nTotalRows, 1);
Group = strings(nTotalRows, 1);
Trial = zeros(nTotalRows, 1);
Foot = strings(nTotalRows, 1);
PeakPressure = zeros(nTotalRows, 1);
ContactArea = zeros(nTotalRows, 1);
ML_Ratio = zeros(nTotalRows, 1);
RegionPressure = zeros(nTotalRows, nRegions);

rowIdx = 1;

for grp = 1:2
    
    if grp == 1
        nPart = N_INJURED;
        prefix = 'INJ';
        mu = injured_mu;
        sd = injured_sd;
        ca_mu = 38;
        lr_mu = 1050;
        groupLabel = "Injured";
    else
        nPart = N_HEALTHY;
        prefix = 'HLT';
        mu = healthy_mu;
        sd = healthy_sd;
        ca_mu = 42;
        lr_mu = 820;
        groupLabel = "Healthy";
    end
    for p = 1:nPart
        pid = sprintf('%s_%02d', prefix, p);

        if grp == 1
            asymFactor = 1.08 + rand * (1.22 - 1.08);
        else
            asymFactor = 0.97 + rand * (1.03 - 0.97);
        end

        for t = 1:N_TRIALS
            for f = 1:2
                if f == 1
                    footLabel = "Left";
                else
                    footLabel = "Right";
                end

                pressures = max(0, mu + sd .* randn(1, nRegions));
                
                if f == 2 && grp == 1
                    pressures = pressures * asymFactor
                end

                medialSum = sum(pressures([1, 3, 7, 8]));
                lateralSum = sum(pressures([2, 4, 5, 6, 9]));
        
                ParticipantID(rowIdx) = pid;
                Group(rowIdx) = groupLabel;
                Trial(rowIdx) = t;
                Foot(rowIdx) = footLabel;
                RegionPressure(rowIdx, :) = round(pressures, 1);
                PeakPressure(rowIdx) = round(max(pressures), 1);
                ContactArea (rowIdx) = round(ca_mu + 4 * randn, 1);
                ML_Ratio (rowIdx) = round(medialSum / lateralSum, 3);

                rowIdx = rowIdx + 1;
            end
        end
    end
end

%%BUILD RESULTS TABLE
T = table(ParticipantID, Group, Trial, Foot, ...
    PeakPressure, ContactArea, ML_Ratio);

for r = 1:nRegions
    colName = matlab.lang.makeValidName(['PP_' regions{r}]);
    T.(colName) = RegionPressure(:, r);
end
disp(T(1:6, 1:7))

%% SUMMARY STATISTICS
injIdx = strcmp(T.Group, "Injured");
hltIdx = strcmp(T.Group, "Healthy");

metrics = {'PeakPressure','ContactArea','ML_Ratio'};
metricNames = {'PeakPressure (kPa)','Contact Area (cm2)','M/L Ratio'};

fprintf('\n=== Key Metrics : Injured vs Healthy ===\n');
fprintf('%-25s %10s %10s %10s %8s\n', 'Metric','Inj Mean','Hlt Mean','Delta','p-value');
fprintf('%\n', repmat('-',1,65));

for m = 1:numel(metrics)
    injVals = T.(metrics{m})(injIdx);
    hltVals = T.(metrics{m})(hltIdx);
    [~, pval]= ttest2(injVals, hltVals);
    fprintf('%-25s %10.2f %10.2f %10.2f %8.4f\n',...
        metricNames{m}, mean(injVals), mean(hltVals), ...
        mean(injVals) - mean(hltVals), pval);
end

%% REGIONAL PRESSURE SUMMARY
fprintf('\n=== Regional Pressure Summary (kPa) ===\n');
fprintf('%-22s %10s %10s %10s %8s\n', 'Region','Injured','Healthy','Delta','%Change');
fprintf('%s\n', repmat('-',1,64));

for r =1:nRegions
    colName = matlab.lang.makeValidName(['PP_' regions{r}]);
    injMean = mean(T.(colName)(injIdx));
    hltMean = mean(T.(colName)(hltIdx));
    delta = injMean - hltMean;
    pct = (delta / hltMean) * 100;
    fprintf('%-22s %10.1f % 10.1f %10.1f %7.1f%%\n', ...
        regions{r}, injMean, hltMean, delta, pct);
end

%% FIGURES
injIdx = strcmp(T.Group, "Injured");
hltIdx = strcmp(T.Group, "Healthy");

injRegMeans = zeros(1, nRegions);
hltRegMeans = zeros(1, nRegions);
for r = 1:nRegions
    colName = matlab.lang.makeValidName(['PP_' regions{r}]);
    injRegMeans(r) = mean(T.(colName)(injIdx));
    hltRegMeans(r) = mean(T.(colName)(hltIdx));
end

figure('Name','Regional Pressure','Position',[100 100 900 500]);
b = bar([injRegMeans; hltRegMeans]','grouped');
b(1).FaceColor = [0.75 0.22 0.17];
b(2).FaceColor = [0.10 0.23 0.36];

set(gca, 'XTick', 1:nRegions, ...
    'XTickLabel', regions, ...
    'XTickLabelRotation', 30, ...
    'FontSize', 10, ...
    'Box', 'off');
ylabel('Mean Peak Pressure (kPa)');
title('Plantar Pressure by Foot Region - Releve', ...
    'FontSize', 13, 'FontWeight','bold');
legend({'Injured','Healthy'}, 'Location', 'northeast');
grid on;

figure('Name','Asymmetry Index','Position',[100 650 500 400]);

pids = unique(T.ParticipantID);
AI_pp = zeros(numel(pids), 1);
AI_grp = strings(numel(pids), 1);

for i = 1:numel(pids)
    pidRows = strcmp(T. ParticipantID, pids(i));
    leftPP = mean(T.PeakPressure(pidRows & strcmp(T.Foot, "Left")));
    rightPP = mean(T.PeakPressure(pidRows & strcmp(T.Foot, "Right")));
    AI_pp(i) = abs(leftPP - rightPP) / ((leftPP + rightPP)/ 2) * 100;
    AI_grp(i) = T.Group(find(pidRows, 1));
end

injAI = AI_pp(strcmp(AI_grp, "Injured"));
hltAI = AI_pp(strcmp(AI_grp, "Healthy"));

scatter(ones(size(injAI)) + randn(size(injAI))*0.05, injAI, 60, ...
    [0.75 0.22 0.17], 'filled', 'MarkerFaceAlpha', 0.7);
hold on;
scatter(ones(size(hltAI))*2 + randn(size(hltAI))*0.05, hltAI, 60, ...
    [0.10 0.23 0.36], 'filled', 'MarkerFaceAlpha', 0.7);

yline(10, '--r', '10% threshold', 'FontSize', 9);
errorbar ([1 2], [mean(injAI) mean(hltAI)], [std(injAI) std(hltAI)], ...
    'k', 'LineStyle', 'none', 'LineWidth', 2, 'CapSize', 12);

set(gca, 'XTick', [1 2], 'XTickLabel', {'Injured','Healthy'}, ...
   'FontSize', 12, 'FontWeight', 'bold');
grid on;

%% EXPORT
writetable(T, 'plantar_pressure_data.csv');
fprintf('\nData saved to plantar_pressure_data.csv\n');
fprintf('Complete!\n');

