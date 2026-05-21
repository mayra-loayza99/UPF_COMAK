%% test_bilateral_comak.m
% Standalone test for single-leg COMAK workflow using model_two_legs_fixed.osim.
% Set SIDE = 'r' or 'l' to analyse the right or left knee.
%
% BEFORE RUNNING:
%   1. Run scale_two_legs_from_existing.py to generate model_two_legs_<ID>.osim
%   2. Set the five parameters below.
%
% USAGE:
%   cd to matlab_scripts/ then run:
%       test_bilateral_comak
%
% Author: Mayra Loayza

close all; clc;
import org.opensim.modeling.*
Logger.setLevelString('Info');

% ── USER SETTINGS ─────────────────────────────────────────────────────────────

TESTING_DIR  = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data';
TEST_SUBJECT = 'HOLOA_040';   % folder name inside TESTING_DIR
PROJECT_ID   = 'HOLOA';
NUMERIC_ID   = '040';         % 3-digit ID used in result file names
SIDE         = 'r';           % 'r' = right knee  |  'l' = left knee

% ─────────────────────────────────────────────────────────────────────────────

currentDir    = fileparts(mfilename('fullpath'));
subject_dir   = fullfile(TESTING_DIR, TEST_SUBJECT);
model_dir     = fullfile(subject_dir, 'model');
walking_dir   = fullfile(subject_dir, 'walking');
results_base  = ['walking_' NUMERIC_ID];

% ── Locate input files ────────────────────────────────────────────────────────
% Prefer the bilateral model (two_legs); fall back to any .osim
model_files = dir(fullfile(model_dir, '*two_legs*.osim'));
if isempty(model_files)
    model_files = dir(fullfile(model_dir, '*.osim'));
end
if isempty(model_files)
    error('No .osim file found in %s — run scale_two_legs_from_existing.py first.', model_dir);
end
model_file = fullfile(model_files(1).folder, model_files(1).name);

trc_files = dir(fullfile(walking_dir, '*.trc'));
if isempty(trc_files)
    error('No TRC file found in %s', walking_dir);
end
motion_file = fullfile(trc_files(1).folder, trc_files(1).name);

% Build external loads file from GRF .mot
grf_files = dir(fullfile(walking_dir, '*.mot'));
if isempty(grf_files)
    error('No GRF .mot file found in %s', walking_dir);
end
grf_file = fullfile(grf_files(1).folder, grf_files(1).name);
template_file = fullfile(currentDir, '../data/template_ext_loads.xml');
createExternalLoadsXML(grf_files(1).name, template_file, walking_dir);
ext_loads_files = dir(fullfile(walking_dir, '*loads.xml'));
ext_load_file   = fullfile(ext_loads_files(1).folder, ext_loads_files(1).name);

% ── Read heel-strike times ────────────────────────────────────────────────────
event_files = dir(fullfile(walking_dir, '*Event*'));
if isempty(event_files)
    error('No Event file found in %s', walking_dir);
end
hs_data    = readtable(fullfile(event_files(1).folder, event_files(1).name), ...
                       'FileType','text','Delimiter','\t','HeaderLines',7);
time_start = hs_data.eRHS(1);
time_stop  = hs_data.eRHS(2);

fprintf('\n==============================================\n');
fprintf('BILATERAL COMAK TEST\n');
fprintf('Subject  : %s_%s\n', PROJECT_ID, NUMERIC_ID);
fprintf('Model    : %s\n', model_files(1).name);
fprintf('TRC      : %s\n', trc_files(1).name);
fprintf('GRF      : %s\n', grf_files(1).name);
fprintf('Time     : %.3f – %.3f s\n', time_start, time_stop);
fprintf('==============================================\n');

% ── Create result directories ─────────────────────────────────────────────────
result_root = fullfile(currentDir, '../results', [PROJECT_ID '_' NUMERIC_ID]);
ik_dir      = fullfile(result_root, 'comak_inverse_kinematics');
comak_dir   = fullfile(result_root, 'comak');
jm_dir      = fullfile(result_root, 'joint_mechanics');
inputs_dir  = fullfile(currentDir, '../inputs', [PROJECT_ID '_' NUMERIC_ID]);

for d = {ik_dir, comak_dir, jm_dir, inputs_dir}
    if ~isfolder(d{1}), mkdir(d{1}); end
end

% ── STEP 1 — Inverse Kinematics ───────────────────────────────────────────────
fprintf('\n--- STEP 1/3: IK (side=%s) ---\n', SIDE);
t_ik = tic;
try
    run_ik(model_file, motion_file, ik_dir, NUMERIC_ID, PROJECT_ID, results_base, time_start, time_stop, SIDE);
    fprintf('IK completed in %.1f s\n', toc(t_ik));
catch ME
    fprintf('ERROR in IK: %s\n', ME.message);
    fprintf('Stack: %s line %d\n', ME.stack(1).name, ME.stack(1).line);
    return
end
java.lang.System.gc(); pause(0.5);

% ── STEP 2 — COMAK ────────────────────────────────────────────────────────────
fprintf('\n--- STEP 2/3: COMAK (side=%s) ---\n', SIDE);
t_comak = tic;
try
    run_comak(model_file, ext_load_file, comak_dir, NUMERIC_ID, PROJECT_ID, results_base, time_start, time_stop, 100, false, [], 0, [], SIDE);
    fprintf('COMAK completed in %.1f s\n', toc(t_comak));
catch ME
    fprintf('ERROR in COMAK: %s\n', ME.message);
    fprintf('Stack: %s line %d\n', ME.stack(1).name, ME.stack(1).line);
    return
end
java.lang.System.gc(); pause(0.5);

% ── STEP 3 — Joint Mechanics ──────────────────────────────────────────────────
fprintf('\n--- STEP 3/3: JOINT MECHANICS ---\n');
t_jm = tic;
try
    run_joint_mechanics(model_file, comak_dir, jm_dir, NUMERIC_ID, PROJECT_ID, results_base, time_start, time_stop);
    fprintf('Joint Mechanics completed in %.1f s\n', toc(t_jm));
catch ME
    fprintf('ERROR in Joint Mechanics: %s\n', ME.message);
    fprintf('Stack: %s line %d\n', ME.stack(1).name, ME.stack(1).line);
    return
end

% ── Summary ───────────────────────────────────────────────────────────────────
fprintf('\n==============================================\n');
fprintf('TEST COMPLETE\n');
fprintf('IK       : %.1f s\n', toc(t_ik) - toc(t_comak));
fprintf('Results  : %s\n', result_root);
fprintf('\nKey output files to inspect:\n');
fprintf('  IK kinematics  : %s/%s_ik.mot\n', ik_dir, results_base);
fprintf('  COMAK states   : %s/%s_states.sto\n', comak_dir, results_base);
fprintf('  Forces         : %s/%s_ForceReporter_forces.sto\n', jm_dir, results_base);
fprintf('==============================================\n');
