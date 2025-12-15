% MATLAB Script: Filter, Summarize, and Visualize BOTH Crime Datasets
%
% This script performs a complete analysis on both the Campus Security Authority
% data and the NIBRS data using provided lookup files.
%
% FIX APPLIED: Hyper-robust data type conversion for the NIBRS Incident Hour 
% column to guarantee the histogram plot appears.

clc;
clear;
close all;

%% --- Global Settings and Constants ---
output_filename_campus = 'filtered_violent_crime_data_CAMPUS.csv';
output_filename_nibrs = 'filtered_violent_crime_data_NIBRS.csv';

% NIBRS Group A Violent Crime Codes for filtering
NIBRS_VIOLENT_CODES = {'09A', '09B', '100', '11A', '11B', '11C', '11D', '120', '13A', '13B'};


%% =========================================================================
%  PART 1: CAMPUS SECURITY AUTHORITY DATA ANALYSIS
%  =========================================================================

fprintf('\n\n=========================================================\n');
fprintf('STARTING ANALYSIS: Campus Security Authority Data\n');
fprintf('=========================================================\n');

% --- 1. Load Data and Filter ---
input_filename_campus = 'Campus Security Authority System - Campus Security Authority System.csv.csv';
OFFENSE_COL_CAMPUS = 'Nature of the Offense';
LOCATION_COL_CAMPUS = 'General Location';
DATETIME_COL_CAMPUS = 'Date Time Occurred';

fprintf('Reading Campus file: %s\n', input_filename_campus);
% Use 'VariableNamingRule', 'preserve' and 'TextType', 'string' for robust loading
T = readtable(input_filename_campus, 'TextType', 'string', 'VariableNamingRule', 'preserve');
fprintf('Total original records: %d\n', height(T));

% Define keywords and apply filter
violent_keywords = {'Homicide', 'Murder', 'Manslaughter', 'Rape', ...
                    'Sexual Assault', 'Robbery', 'Assault', 'Battery', ...
                    'Kidnapping', 'Abduction'};
is_violent_crime = false(height(T), 1);
for i = 1:length(violent_keywords)
    is_violent_crime = is_violent_crime | contains(T.(OFFENSE_COL_CAMPUS), violent_keywords{i}, 'IgnoreCase', true);
end
T_campus_filtered = T(is_violent_crime, :);
fprintf('Violent crime records found (Campus): %d\n', height(T_campus_filtered));

% --- 2. Save Filtered Data ---
writetable(T_campus_filtered, output_filename_campus);
fprintf('Filtered Campus data saved to: %s\n', output_filename_campus);

% --- 3. Summary and Plotting Prep ---
if height(T_campus_filtered) == 0
    fprintf('No violent crime records found in Campus data for plotting.\n');
else
    % Offense Summary Table
    OffenseCat = categorical(T_campus_filtered.(OFFENSE_COL_CAMPUS));
    [Counts, Categories] = groupcounts(OffenseCat);
    T_Offense_Summary = sortrows(table(Categories, Counts, 'VariableNames', {'Offense_Type', 'Total_Count'}), 'Total_Count', 'descend');

    % Location Summary Table
    LocationCat = categorical(strtrim(T_campus_filtered.(LOCATION_COL_CAMPUS)));
    [Counts_Loc, Categories_Loc] = groupcounts(LocationCat);
    T_Location_Summary = sortrows(table(Categories_Loc, Counts_Loc, 'VariableNames', {'Location_Name', 'Total_Count'}), 'Total_Count', 'descend');

    % --- 4. Generate Visualizations (Campus) ---
    N_TOP = 10;
    
    % A. Bar Chart: Top 10 Offense Types (Figure 1)
    figure('Name', 'Campus - Top Offenses Bar Chart');
    TopOffenses = T_Offense_Summary(1:min(N_TOP, height(T_Offense_Summary)), :);
    bar(TopOffenses.Offense_Type, TopOffenses.Total_Count, 'FaceColor', [0.1 0.5 0.7]);
    title('Campus Data: Top Violent Crime Offense Types');
    xlabel('Offense Type'); ylabel('Total Count of Incidents'); grid on; xtickangle(45);

    % B. Bar Chart: Top 10 General Locations (Figure 2)
    figure('Name', 'Campus - Top Locations Bar Chart');
    TopLocations = T_Location_Summary(1:min(N_TOP, height(T_Location_Summary)), :);
    bar(TopLocations.Location_Name, TopLocations.Total_Count, 'FaceColor', [0.8 0.4 0.1]);
    title('Campus Data: Top Locations for Violent Crime Incidents');
    xlabel('General Location'); ylabel('Total Count of Incidents'); grid on; xtickangle(45);

    % C. Pie Chart: Top 5 Offense Types (Figure 3)
    figure('Name', 'Campus - Top Offenses Pie Chart');
    N_Pie = min(5, height(T_Offense_Summary));
    TopOffenses_Pie = T_Offense_Summary(1:N_Pie, :);
    Counts_Pie = TopOffenses_Pie.Total_Count;
    Labels = TopOffenses_Pie.Offense_Type;
    if height(T_Offense_Summary) > N_Pie
        Counts_Pie = [Counts_Pie; sum(T_Offense_Summary.Total_Count(N_Pie+1:end))];
        Labels = [Labels; "Other"];
    end
    pie(Counts_Pie);
    title('Campus Data: Distribution of Violent Crime Offenses (Top Categories)');
    LegendLabels = arrayfun(@(c, l) sprintf('%s (n=%d)', l, c), Counts_Pie, Labels, 'UniformOutput', false);
    legend(LegendLabels, 'Location', 'southoutside', 'Orientation', 'horizontal');

    % D. Histogram: Crime Frequency by Hour of Day (Figure 4)
    figure('Name', 'Campus - Hourly Crime Frequency Histogram');
    DateTimeOccurred = datetime(T_campus_filtered.(DATETIME_COL_CAMPUS), 'InputFormat', 'MM/dd/yyyy HH:mm:ss a', 'Format', 'HH:mm:ss');
    CrimeHour = hour(DateTimeOccurred);
    histogram(CrimeHour, 'Normalization', 'count', 'BinMethod', 'integers');
    title('Campus Data: Violent Crime Frequency by Hour of Day');
    xlabel('Hour of Day (24-Hour Clock)'); ylabel('Number of Incidents');
    xlim([-0.5 23.5]); xticks(0:23); grid on;
end

%% =========================================================================
%  PART 2: NIBRS DATA ANALYSIS
%  =========================================================================

fprintf('\n\n=========================================================\n');
fprintf('STARTING ANALYSIS: NIBRS Data\n');
fprintf('=========================================================\n');

% --- 1. Load All NIBRS Files ---
try
    % Core data (offense codes, location IDs)
    T_NIBRS = readtable('NIBRS_OFFENSE - NIBRS_OFFENSE.csv.csv', 'TextType', 'string');
    
    % Lookup tables
    T_OffenseType = readtable('NIBRS_OFFENSE - offense-type.csv', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    T_LocationType = readtable('NIBRS_OFFENSE - location-type.csv', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    T_IncidentSheet = readtable('NIBRS_OFFENSE - incident sheet.csv', 'TextType', 'string');

    fprintf('Successfully loaded all NIBRS data files.\n');
catch ME
    fprintf('Error loading NIBRS files: %s\n', ME.message);
    fprintf('Skipping NIBRS analysis.\n');
    return;
end

% --- 2. Filter NIBRS Core Data for Violent Crimes ---
is_nibrs_violent = ismember(T_NIBRS.offense_code, NIBRS_VIOLENT_CODES);
T_NIBRS_filtered = T_NIBRS(is_nibrs_violent, :);
fprintf('Violent crime records found (NIBRS core): %d\n', height(T_NIBRS_filtered));

if height(T_NIBRS_filtered) == 0
    fprintf('No violent crime records found in NIBRS data for analysis.\n');
    return;
end

% --- 3. Join with Lookup Tables for Descriptive Names and Hour ---

% A. Join with Offense Type (get descriptive name)
T_OffenseType.Properties.VariableNames{'offense_name'} = 'Offense_Name';
T_NIBRS_merged = innerjoin(T_NIBRS_filtered, T_OffenseType(:, {'offense_code', 'Offense_Name'}), ...
    'Keys', 'offense_code');

% B. Join with Location Type (get descriptive name)
T_LocationType.Properties.VariableNames{'location_name'} = 'Location_Name';
T_NIBRS_merged = innerjoin(T_NIBRS_merged, T_LocationType(:, {'location_id', 'Location_Name'}), ...
    'Keys', 'location_id');

% C. Join with Incident Sheet (get hour)
T_IncidentSheet.Properties.VariableNames{'incident_hour'} = 'Incident_Hour';
T_NIBRS_merged = innerjoin(T_NIBRS_merged, T_IncidentSheet(:, {'incident_id', 'Incident_Hour'}), ...
    'Keys', 'incident_id');

T_NIBRS_final = T_NIBRS_merged;
fprintf('Final NIBRS records after joins: %d\n', height(T_NIBRS_final));

% --- 4. Save Filtered Data ---
writetable(T_NIBRS_final, output_filename_nibrs);
fprintf('Filtered NIBRS data saved to: %s\n', output_filename_nibrs);

% --- 5. Summary and Plotting Prep ---

% Offense Summary Table
OffenseCat_N = categorical(T_NIBRS_final.Offense_Name);
[Counts_N, Categories_N] = groupcounts(OffenseCat_N);
T_Offense_Summary_N = sortrows(table(Categories_N, Counts_N, 'VariableNames', {'Offense_Type', 'Total_Count'}), 'Total_Count', 'descend');

% Location Summary Table
LocationCat_N = categorical(T_NIBRS_final.Location_Name);
[Counts_Loc_N, Categories_Loc_N] = groupcounts(LocationCat_N);
T_Location_Summary_N = sortrows(table(Categories_Loc_N, Counts_Loc_N, 'VariableNames', {'Location_Name', 'Total_Count'}), 'Total_Count', 'descend');


% --- 6. Generate Visualizations (NIBRS) ---
N_TOP = 10;
    
% A. Bar Chart: Top 10 Offense Types (Figure 5)
figure('Name', 'NIBRS - Top Offenses Bar Chart');
TopOffenses_N = T_Offense_Summary_N(1:min(N_TOP, height(T_Offense_Summary_N)), :);
bar(TopOffenses_N.Offense_Type, TopOffenses_N.Total_Count, 'FaceColor', [0.1 0.7 0.5]);
title('NIBRS Data: Top Violent Crime Offense Types');
xlabel('Offense Type'); ylabel('Total Count of Incidents'); grid on; xtickangle(45);

% B. Bar Chart: Top 10 General Locations (Figure 6)
figure('Name', 'NIBRS - Top Locations Bar Chart');
TopLocations_N = T_Location_Summary_N(1:min(N_TOP, height(T_Location_Summary_N)), :);
bar(TopLocations_N.Location_Name, TopLocations_N.Total_Count, 'FaceColor', [0.7 0.1 0.5]);
title('NIBRS Data: Top 10 Locations for Violent Crime Incidents');
xlabel('General Location'); ylabel('Total Count of Incidents'); grid on; xtickangle(45);

% C. Pie Chart: Top 5 Offense Types (Figure 7)
figure('Name', 'NIBRS - Top Offenses Pie Chart');
N_Pie = min(5, height(T_Offense_Summary_N));
TopOffenses_Pie_N = T_Offense_Summary_N(1:N_Pie, :);
Counts_Pie_N = TopOffenses_Pie_N.Total_Count;
Labels_N = TopOffenses_Pie_N.Offense_Type;
if height(T_Offense_Summary_N) > N_Pie
    Counts_Pie_N = [Counts_Pie_N; sum(T_Offense_Summary_N.Total_Count(N_Pie+1:end))];
    Labels_N = [Labels_N; "Other"];
end
pie(Counts_Pie_N);
title('NIBRS Data: Distribution of Violent Crime Offenses (Top Categories)');
LegendLabels_N = arrayfun(@(c, l) sprintf('%s (n=%d)', l, c), Counts_Pie_N, Labels_N, 'UniformOutput', false);
legend(LegendLabels_N, 'Location', 'southoutside', 'Orientation', 'horizontal');


% D. Histogram: Crime Frequency by Hour of Day (Figure 8)
figure('Name', 'NIBRS - Hourly Crime Frequency Histogram');

% --- HYPER-ROBUST CONVERSION FIX ---
HourData = T_NIBRS_final.Incident_Hour;

% 1. Force to string array for uniform cleaning
if isnumeric(HourData)
    % Handle case where 'readtable' was overridden or column was numeric after join
    HourStrings = string(HourData);
elseif iscell(HourData)
    HourStrings = string(HourData);
elseif iscategorical(HourData)
    HourStrings = string(HourData);
else
    HourStrings = HourData; % Assume string array
end

% 2. Clean up known missing value strings (e.g., 'nan') and empty strings
% Sets them to MATLAB's missing string value (<missing>)
HourStrings(strcmpi(strtrim(HourStrings), 'nan')) = missing;
HourStrings(strtrim(HourStrings) == "") = missing;
HourStrings = strtrim(HourStrings); % Remove trailing/leading spaces

% 3. Convert to double. str2double on a string array converts <missing> to NaN
CrimeHour_N = str2double(HourStrings);

% 4. Final cleanup: Remove NaN values before plotting
CrimeHour_N(isnan(CrimeHour_N)) = []; 

% Check if there is data left to plot
if isempty(CrimeHour_N)
    disp('CRITICAL ERROR: CrimeHour data is empty after cleanup. Histogram cannot be plotted.');
else
    histogram(CrimeHour_N, 'Normalization', 'count', 'BinMethod', 'integers');
    title('NIBRS Data: Violent Crime Frequency by Hour of Day');
    xlabel('Hour of Day (24-Hour Clock)'); ylabel('Number of Incidents');
    xlim([-0.5 23.5]); xticks(0:23); grid on;
end

% --- END OF SCRIPT ---