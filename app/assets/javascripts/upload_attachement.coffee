uploadAttachment = (attachment) ->
# Create our form data to submit
  file = attachment.file
  form = new FormData
  form.append 'Content-Type', file.type
  form.append 'photo[image]', file
  # Create our XHR request
  xhr = new XMLHttpRequest
  xhr.open 'POST', '/photos.json', true
  xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
  # Report file uploads back to Trix

  xhr.upload.onprogress = (event) ->
    progress = event.loaded / event.total * 100
    attachment.setUploadProgress progress
    return

  # Tell Trix what url and href to use on successful upload

  xhr.onload = ->
    if xhr.status == 201
      data = JSON.parse(xhr.responseText)
      return attachment.setAttributes(
        url: data.image_url
        href: data.url)
    return

  xhr.send form


$(document).ready ->
  document.addEventListener 'trix-attachment-add', (event) ->
    attachment = event.attachment
    if attachment.file
      return uploadAttachment(attachment)
    return
  return

