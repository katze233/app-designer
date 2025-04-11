clc;
clear;

%TCP 
host = "10.203.196.138";
port = 5025;
t = tcpclient(host, port, "Timeout", 20);
interface = t;
data = table();

% scatter 
figure(1);
mainAx = gca;
title(mainAx, 'Real-time Scatter of ux and uy');
xlabel(mainAx, 'uxVoltage');
ylabel(mainAx, 'uyVoltage');
grid(mainAx, 'on');

% heat map
figure(2);
spotAx = gca;

sampleIndex = 0;

writeline(interface, "INITiate:CONTinuous:ALL ON");

%
n = 60*60*6;
while n > 1
    writeline(interface, "DATA:POINTS?");
    pause(0.3);

    if interface.NumBytesAvailable > 0
        countStr = readline(interface);
        count = str2double(strtrim(countStr));
        disp("points: " + count);
    else
        disp("no return points");
        count = 0;
    end

    if count > 0
        writeline(interface, "DATA:REMOVE? " + num2str(count));
        pause(0.3);

        while count > 0
            if interface.NumBytesAvailable > 0
                line1 = strtrim(readline(interface));
                disp("line: " + line1);

                if strlength(line1) > 0
                    writelines(line1, '2025-07-04a_esp32_testdaten_all.txt', WriteMode="append", LineEnding=" ");

                    parts = split(line1, ',');
                    if numel(parts) >= 12
                        ux = str2double(parts(10));
                        uy = str2double(parts(11));
                        us = str2double(parts(12));

                        if all(~isnan([ux, uy, us]))
                            sampleIndex = sampleIndex + 1;
                            data(end+1, :) = table(ux, uy, us, ...
                                'VariableNames', {'uxVoltage', 'uyVoltage', 'usVoltage'});

                            if height(data) > 300
                                data = tail(data, 300);
                            end

                            %  scatter
                            cla(mainAx);
                            hold(mainAx, 'on'); 
                            % xlim(mainAx, [-1,1]);
                            % ylim(mainAx, [-1,1]);
                            x_min = min(ux);
                            x_max = max(ux);
                            y_min = min(uy);
                            y_max = max(uy);

                            axis_limit = max(abs([x_min, x_max, y_min, y_max]));
                            x_min = -axis_limit;
                            x_max = axis_limit;
                            y_min = -axis_limit;
                            y_max = axis_limit;


                            x_margin = 0.02; % extra margin
                            y_margin = 0.02;

                            xlim(mainAx, [x_min - x_margin, x_max + x_margin]);
                            ylim(mainAx, [y_min - y_margin, y_max + y_margin]);

                            % Set X/Y axis scale (0.05 interval)
                            x_step = 0.05;
                            y_step = 0.05;
                            xticks(mainAx, x_min:x_step:x_max);
                            yticks(mainAx, y_min:y_step:y_max);
                           
                            scatter(mainAx, ux, uy, 60, us, 'filled');
                            
                            plot(mainAx, [x_min, x_max], [0, 0], 'k-', 'LineWidth', 1.5); % X axis
                            plot(mainAx, [0, 0], [y_min, y_max], 'k-', 'LineWidth', 1.5); % Y axis

                            
                            text(mainAx, ux + 0.005, uy + 0.005, ...
                                sprintf('(%.5f, %.5f)', ux, uy), ...
                                'Color', 'b', 'FontSize', 8, 'FontWeight', 'bold');
                            colormap(mainAx, turbo);
                            colorbar(mainAx);
                            title(mainAx, 'Latest ux vs uy');
                            xlabel(mainAx, 'uxVoltage');
                            ylabel(mainAx, 'uyVoltage');
                            grid(mainAx, 'on');


                            %  Figure 2

                            updateSpotOffset(data, spotAx);
                            drawnow limitrate;
                        end
                    end
                end
                count = count - 1;
            else
                pause(0.05);
            end
        end
    end


    line2 = writeread(interface, "SYSTem:DEBUg:MEMory?");
    writelines(line2, '2025-07-04a_esp32_memorydaten.txt', WriteMode="append", LineEnding=" ");
end

updateSpotOffset(data, spotAx);
writeread(interface, "INITiate:CONTinuous OFF");
clear interface

function updateSpotOffset(data, spotAx)
    N = 30;
    if height(data) > N
        recentData = tail(data, N);
    else
        recentData = data;
    end

    allX = recentData.uxVoltage;
    allY = recentData.uyVoltage;
    allZ = recentData.usVoltage;

    if sum(allZ) == 0 || any(isnan(allZ))
        disp("skip");
        return;
    end

    cla(spotAx);
    hold(spotAx, 'on');

    x_range = linspace(min(allX), max(allX), 50);
    y_range = linspace(min(allY), max(allY), 50);
    [X, Y] = meshgrid(x_range, y_range);

    % F = scatteredInterpolant(allX, allY, allZ, 'linear', 'none');
    % Z = F(X, Y);
     Z = griddata(allX, allY, allZ, X, Y, 'cubic');

    xMin = min(allX);
    xMax = max(allX);
    if xMin == xMax
        xMin = xMin - 0.01;
        xMax = xMax + 0.01;
    end
    xlim(spotAx, [xMin, xMax]);

    yMin = min(allY);
    yMax = max(allY);
    if yMin == yMax
        yMin = yMin - 0.01;
        yMax = yMax + 0.01;
    end
    ylim(spotAx, [yMin, yMax]);
 
    % Compute intensity-weighted centroid of the laser spot
    x0 = sum(allX .* allZ) / sum(allZ);
    y0 = sum(allY .* allZ) / sum(allZ);
    
    deltaX = x0;
    deltaY = y0;

    % Plot heatmap of laser spot intensity
    imagesc(spotAx, x_range, y_range, Z);
    axis(spotAx, 'tight');
    axis(spotAx, 'equal');
    set(spotAx, 'YDir', 'normal');
    colormap(spotAx, turbo);
    colorbar(spotAx);

    % Draw dashed lines for origin axes
    plot(spotAx, [min(x_range), max(x_range)], [0, 0], 'k--');
    plot(spotAx, [0, 0], [min(y_range), max(y_range)], 'k--');
 
    % Plot center point (centroid) in red
    plot(spotAx, x0, y0, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    scatter(spotAx, allX, allY, 30, allZ, 'filled', 'MarkerEdgeColor', 'k');

    % Label the center point
    text(spotAx, x0 + 0.01, y0 + 0.005, 'central point', 'Color', 'r', 'FontSize', 10);
    text(spotAx, x0, y0 - 0.02, sprintf('ΔX = %.3f\nΔY = %.3f',deltaX, deltaY), ...
        'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');

    % Draw offset arrow from (0,0) to the actual center
    quiver(spotAx, 0, 0, x0, y0, 0, 'b--', 'LineWidth', 2, 'MaxHeadSize', 0.5);
    plot(spotAx, 0, 0, 'wx', 'MarkerSize', 10, 'LineWidth', 2);

    xlabel(spotAx, 'X position');
    ylabel(spotAx, 'Y position');
    title(spotAx, 'Laser Spot Offset');
    hold(spotAx, 'off');
end