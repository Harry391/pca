function packet = read_realtime_camera_service_frame(service, lastSequence)
%READ_REALTIME_CAMERA_SERVICE_FRAME Read the latest service frame if it is new.

    if nargin < 2
        lastSequence = -1;
    end
    packet = runtime_read_camera_frame(service, lastSequence);
end
