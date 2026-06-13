function state = clear_image_state(state)
%CLEAR_IMAGE_STATE Reset image-related fields.

    state.currentImage = [];
    state.currentImagePath = "";
    state.currentGrayImage = [];
    state.currentFaceBox = [];
    state.currentAlignedFace = [];
end

