function draws = simulate_arx_bootstrap(model, y_history, h, B, x_future)
%SIMULATE_ARX_BOOTSTRAP Simulate h-step ARX forecasts by residual bootstrap.
%
% draws = SIMULATE_ARX_BOOTSTRAP(model, y_history, h, B, x_future) returns a
% B-by-1 vector of simulated y_{t+h}. x_future can be empty, an h-by-nx
% matrix, or an h-by-nx-by-B array. When the model has exogenous regressors
% and x_future is empty, future x values are sampled from model.x_pool.

if nargin < 5
    x_future = [];
end

y_history = double(y_history(:));
y_history = y_history(isfinite(y_history));
if numel(y_history) < model.p
    error('simulate_arx_bootstrap:ShortHistory', ...
        'Need at least p finite observations in y_history.');
end
if isempty(model.residuals)
    error('simulate_arx_bootstrap:NoResiduals', ...
        'Model residuals are empty.');
end

h = max(1, round(h));
B = max(1, round(B));
draws = NaN(B, 1);
resid = model.residuals(:);

for b = 1:B
    y_state = y_history((end - model.p + 1):end)';
    for step = 1:h
        row = build_row(model, y_state, step, b, x_future);
        e = resid(randi(numel(resid)));
        y_next = row * model.beta + e;
        y_state = [y_next, y_state(1:(end - 1))]; %#ok<AGROW>
    end
    draws(b) = y_state(1);
end
end

function row = build_row(model, y_state, step, b, x_future)
row = [];
if model.include_const
    row = 1;
end
row = [row, y_state]; %#ok<AGROW>

if model.nx == 0
    return;
end

if isempty(x_future)
    if isempty(model.x_pool)
        x_row = zeros(1, model.nx);
    else
        x_row = model.x_pool(randi(size(model.x_pool, 1)), :);
    end
elseif ndims(x_future) == 3
    x_row = squeeze(x_future(step, :, b))';
else
    x_row = x_future(step, :);
end

row = [row, x_row]; %#ok<AGROW>
end
