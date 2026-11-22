-- Colors and sizes of the chat window, in one place.
-- Colors are { r, g, b } in [0, 1].

local function rgb(r, g, b)
    return { r = r / 255, g = g / 255, b = b / 255 }
end

local ChatTheme = {
    accent         = rgb(201, 162, 74), -- muted gold: active tab, unread dot, focused input, active icons
    titleBar       = rgb(21, 21, 21),
    body           = rgb(28, 28, 28),
    tabStrip       = rgb(25, 25, 25),
    separator      = rgb(44, 44, 44),
    inputBorder    = rgb(58, 58, 58),
    textActive     = rgb(244, 244, 244),
    textMuted      = rgb(163, 163, 163),
    textHover      = rgb(215, 215, 215),
    iconIdle       = rgb(169, 169, 169),
    pill           = rgb(0, 0, 0),
    chip           = rgb(58, 58, 58),  -- channel label in the input box

    bodyOpacity    = 0.92, -- multiplied by the player's chat opacity settings
    stripeOpacity  = 0.045,
    inputOpacity   = 0.35,
    pillOpacity    = 0.55,

    iconSize       = 14,
    inputPadding   = 6,  -- space between the window border and the input box
    chipMargin     = 6,  -- space between the input box border and the channel label
    chipPaddingX   = 6,
    buttonGap      = 2,
    textPaddingX   = 12,
    textPaddingTop = 6,
    wrapIndent     = 16, -- continuation lines of a wrapped message

    -- bubbles: maximum width of the text before it wraps, and a tint applied to the bubble
    -- textures (dark grey fill, white border) to match the chat window palette
    bubbleMaxTextWidth = 280,
    bubbleTint     = 0.72,
    bubbleGrowMs   = 120, -- time for a bubble to grow by one line when a new line starts

    -- HUD mode (chat not focused): how fast older messages fade out
    hudFadePerMessage = 0.16,
}

ChatTheme.icons = {
    close   = 'media/ui/tics/icons/chat-close.png',
    lock    = 'media/ui/tics/icons/chat-lock.png',
    unlock  = 'media/ui/tics/icons/chat-unlock.png',
    gear    = 'media/ui/tics/icons/chat-gear.png',
    info    = 'media/ui/tics/icons/chat-info.png',
    eye     = 'media/ui/tics/icons/chat-eye.png',
    eyeOff  = 'media/ui/tics/icons/chat-eye-off.png',
    eyePlus = 'media/ui/tics/icons/chat-eye-plus.png',
    mic     = 'media/ui/tics/icons/chat-mic.png',
    micOff  = 'media/ui/tics/icons/chat-mic-off.png',
    upload  = 'media/ui/tics/icons/chat-upload.png',
    portrait = 'media/ui/tics/icons/chat-portrait.png',
}

return ChatTheme
