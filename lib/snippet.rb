# https://stackoverflow.com/questions/11234444/ruby-truncate-words-long-text

module Snippet
  
  def snippet str, max_words, max_chars, omission='...'
    max_chars = 1+omision.size if max_chars <= omission.size # need at least one char plus ellipses
    words = str.split
    omit = words.size > max_words || str.length > max_chars ? omission : ''
    snip = words[0...max_words].join ' '
    snip = snip[0...(max_chars-3)] if snip.length > max_chars
    snip + omit
  end

end
