function state = clear_image_state(state)
%CLEAR_IMAGE_STATE Reset image-related fields.

    state.currentImage = [];
    state.currentImagePath = "";
    state.currentGrayImage = [];
    state.currentProcessedImage = [];
    state.currentFaceBox = [];
    state.currentFaceInfo = struct();
    state.currentAlignInfo = struct();
    state.currentAlignedFace = [];
    state.currentCameraFrame = [];
end

