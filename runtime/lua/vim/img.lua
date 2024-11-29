local img = vim._defer_require('vim.img', {
  _image = ...,    --- @module 'vim.img._image'
})

---Loads an image into memory, returning a wrapper around the image.
---
---Accepts `data` as base64-encoded bytes, or a `filename` that will be loaded.
---@param opts {data?:string, filename?:string}
---@return vim.img.Image
function img.load(opts)
  return img._image:new(opts)
end

return img
