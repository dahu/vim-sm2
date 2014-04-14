" The original SM2 algorithm, converted from the Delphi source at
" http://www.supermemo.com/english/ol/sm2source.htm
"
" Barry Arthur, 20140414
"
" Enhanced with due() function to drive revision cycles

function! SM2_DataRecord()
  let obj = {}
  let obj.prior_time = 0
  let obj.interval   = 0
  let obj.repetition = 0
  let obj.ef         = 2.5
  return obj
endfunction

" distance is the number of seconds since the prior_time in each record
" use 3600 to base interval on hours
" use 86400 to base interval on days
function! SM2_SRS(datafile, distance)
  let obj = {}
  let datafile = a:datafile

  if datafile == ''
    throw 'SM2: Must provide a data file: '
  elseif ! filereadable(datafile)
    if writefile([], datafile) == -1
      throw 'SM2: Cannot create file: ' . datafile
    endif
  elseif ! filewritable(datafile)
    throw 'SM2: Cannot write file: ' . datafile
  endif

  let obj.data = {}
  let obj.datafile = datafile
  let obj.distance = a:distance

  func obj.generate_new_id() dict
    " laughable sample data to generate an id from; better to
    " pass your own id into SM2_SRS.new(id)
    let id1 = substitute(tempname(), '/', '', 'g')[-10:-1] .
          \ printf("%010d", abs((getpid() + 1023) * localtime()))
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
    if has_key(self.data, id)
      throw 'SM2: new() : id already exists : ' . id
    endif
    call self.set_data_record(id, SM2_DataRecord())
    return id
  endfunc

  func obj.due() dict
    let ids = []
    let now = localtime()
    for [id, rec] in items(self.data)
      if (rec.prior_time + (rec.interval * self.distance)) < now
        call add(ids, id)
      endif
    endfor
    return ids
  endfunc

  func obj.del(id) dict
    if has_key(self.data, a:id)
      call remove(self.data, a:id)
    endif
    call self.save_data_file()
  endfunc

  func obj.load_data_file(...) dict
    let force = a:0 ? a:1 : 0
    if empty(self.data) || force
      if filereadable(self.datafile)
        let data = readfile(self.datafile)
        if ! empty(data)
          let self.data = eval(join(data, ''))
        endif
      else
        throw "SM2: Cannot find file: " . self.datafile
      endif
    endif
  endfunc

  func obj.get_data_record(id) dict
    let id = a:id
    call self.load_data_file()
    if has_key(self.data, id)
      return self.data[id]
    else
      throw 'SM2: No such element number: ' . id
    endif
  endfunc

  func obj.save_data_file() dict
    if writefile([string(self.data)], self.datafile) == -1
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

    let dr.prior_time = localtime()

    if commit
      call self.set_data_record(id, dr)
    endif

    return dr.interval
  endfunc

  call obj.load_data_file()
  return obj
endfunction
