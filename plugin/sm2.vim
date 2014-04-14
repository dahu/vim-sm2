function! Serialisable(...)
  let obj = a:0 ? a:1 : {}
  func obj.serialise() dict
    return string(filter(self, 'type(v:val) != type(function("len"))'))
  endfunc
  func obj.unserialise(str) dict
    for i in items(eval(a:str))
      let self[i[0]] = i[1]
    endfor
    return self
  endfunc
  return obj
endfunction

function! SM2_DataRecord()
  let obj = Serialisable()
  let obj.interval   = 0
  let obj.repetition = 0
  let obj.ef         = 2.5
  return obj
endfunction

" The original SM2 algorithm, converted from the Delphi source at
" http://www.supermemo.com/english/ol/sm2source.htm
function! SM2_SRS(datafile)
  let obj = {}
  let datafile = a:datafile

  if datafile == ''
    throw 'SM2: Must provide a data file: '
  elseif ! filereadable(datafile)
    throw 'SM2: Cannot find file: ' . datafile
  elseif ! filewritable(datafile)
    throw 'SM2: Cannot write file: ' . datafile
  endif

  let obj.datafile = datafile
  let obj.data = {}

  func obj.generate_new_id() dict
    " laughable sample data to generate an id from; better to
    " pass your own id into SM2_SRS.new(id)
    let id1 = substitute(tempname(), '/', '', 'g')[-9:-1] .
          \ printf("%02d", changenr()%9) .
          \ printf("%09d", (getpid() + 1023) * localtime())
    if exists('*md5#md5')
      return md5#md5(id1)
    else
      return id1
    endif
  endfunc

  func obj.new_id() dict
    let id = self.generate_new_id()
    while has_key(self.data, id)
      let id = self.generate_new_id()
    endwhile
    return id
  endfunc

  func obj.new(...) dict
    let id = ''
    if a:0
      let id = a:1
    endif
    if id == ''
      let id = self.new_id()
    endif
    call self.set_data_record(id, SM2_DataRecord())
    return id
  endfunc

  func obj.due() dict
  endfunc

  func obj.del(id) dict
    if has_key(self.data, a:id)
      call remove(self.data, a:id)
    endif
    call self.save_data_file()
  endfunc

  func obj.get_data_record(id) dict
    let id = a:id
    if filereadable(self.datafile)
      let self.data = map(eval(join(readfile(self.datafile), '')),
      \ 'SM2_DataRecord().unserialise(v:val)')
    else
      throw "SM2: Cannot find file: " . self.datafile
    endif
    if has_key(self.data, id)
      return self.data[id]
    else
      throw 'SM2: No such element number: ' . id
    endif
  endfunc

  func obj.save_data_file() dict
    if writefile([string(map(deepcopy(self.data), 'v:val.serialise()'))],
          \ self.datafile) == -1
      throw 'SM2: Cannot save data. Write failed.'
    endif
  endfunc

  func obj.set_data_record(id, datarecord) dict
    if ! filewritable(self.datafile)
      throw 'SM2: Cannot write file: ' . self.datafile
    else
      let self.data[a:id] = a:datarecord
      call self.save_data_file()
    endif
  endfunc

  func obj.repetition(id, grade, ...) dict
    let id = a:id
    let grade = a:grade
    let commit = a:0 ? a:1 : 1
    let dr = self.get_data_record(id)

    if grade >= 3
      if dr.repetition == 0
        let dr.interval = 1
        let dr.repetition = 1
      elseif dr.repetition == 1
        let dr.interval = 6
        let dr.repetition = 2
      else
        let dr.interval = float2nr(round(dr.interval * dr.ef))
        let dr.repetition += 1
      end
    else
      let dr.repetition = 0
      let dr.interval = 1
    end

    let dr.ef = dr.ef + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02))

    if dr.ef < 1.3
      let dr.ef = 1.3
    end

    if commit
      call self.set_data_record(id, dr)
    endif

    return dr.interval
  endfunc

  return obj
endfunction

let foo = SM2_SRS('test.sm2')

