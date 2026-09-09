function temp_model_file = preparar_modelo_bilateral(model_file, side, result_dir)
% preparar_modelo_bilateral  Prepare bilateral model for single-leg COMAK.
%
%   temp_model_file = preparar_modelo_bilateral(model_file, side, result_dir)
%
%   Loads the bilateral model (model_two_legs_*.osim, which has tf_contact,
%   pf_contact, tf_contact_l, pf_contact_l, muscles _r/_l, ligaments
%   without suffix for right / _l suffix for left), disables every force
%   belonging to the contralateral leg, and saves the modified model to
%   result_dir.
%
%   side = 'r'  →  disable left contacts (tf_contact_l, pf_contact_l),
%                   all muscles ending in _l, all ligaments ending in _l.
%   side = 'l'  →  disable right contacts (tf_contact, pf_contact),
%                   all muscles ending in _r, all ligaments with no
%                   lateral suffix (right ligaments have no _r suffix
%                   in the Lenhart bilateral model).
%
%   The resulting model is saved as:
%       result_dir / <basename>_<side>_prepared.osim
%
%   Force naming in model_two_legs:
%       Muscles       :  baseName_r  /  baseName_l
%       TF contact    :  tf_contact  /  tf_contact_l
%       PF contact    :  pf_contact  /  pf_contact_l
%       Ligaments     :  MCLd1..ITB1 (right, no suffix) /  MCLd1_l..ITB1_l

    import org.opensim.modeling.*

    model = Model(model_file);
    model.initSystem();

    force_set = model.getForceSet();
    n_forces  = force_set.getSize();
    disabled  = 0;

    for i = 0:(n_forces - 1)
        force = force_set.get(i);
        name  = char(force.getName());

        if strcmp(side, 'r')
            % ── Analyzing RIGHT: disable everything that ends with '_l' ──────
            if endsWith(name, '_l')
                force.set_appliesForce(false);
                disabled = disabled + 1;
            end

        else  % side = 'l'
            % ── Analyzing LEFT: disable right-side forces ────────────────────
            if endsWith(name, '_r')
                % Right muscles (addbrev_r, gaslat_r, …)
                force.set_appliesForce(false);
                disabled = disabled + 1;

            elseif ~endsWith(name, '_l') && ~endsWith(name, '_r')
                % Forces with no lateral suffix are right-side contacts and
                % ligaments (tf_contact, pf_contact, MCLd1, ACLpl1, …).
                % Use getConcreteClassName() to avoid disabling other forces
                % (e.g. SpringGeneralizedForce for knee stiffness is named
                % knee_flex_r/_l so it is caught by the endsWith checks above).
                cls = char(force.getConcreteClassName());
                if strcmp(cls, 'Smith2018ArticularContactForce') || ...
                   strcmp(cls, 'Blankevoort1991Ligament')
                    force.set_appliesForce(false);
                    disabled = disabled + 1;
                end
            end
        end
    end

    fprintf('preparar_modelo_bilateral: disabled %d contralateral forces (side=%s)\n', ...
            disabled, side);

    % ── Save prepared model ──────────────────────────────────────────────────
    if ~isfolder(result_dir), mkdir(result_dir); end

    [~, fname, ~] = fileparts(model_file);
    temp_model_file = fullfile(result_dir, [fname '_' side '_prepared.osim']);
    model.print(temp_model_file);
    fprintf('  -> %s\n', temp_model_file);
end
