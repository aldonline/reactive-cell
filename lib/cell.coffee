reactivity = require 'reactivity'

class ReadOnlyError extends Error

class Box
  # throws error or returns value
  do_get: -> if @is_error then throw @v else @v
  # returns true if something changed, false otherwise
  do_set: ( e, r ) ->
    new_v = if ( is_error = e? ) then e else r
    return false if new_v is @v
    @is_error = is_error
    @v = new_v
    yes

  # will figure out values being passed
  # f(e), f(r), f(e, r)
  do_set_auto: -> 
    a = arguments
    if a.length is 2 then return @do_set.apply @, a # f( error, response )
    # otherwise it has to be 1
    # ( we don't check since this is an internal helper for this module )
    if a[0] instanceof Error
      @do_set a[0], null
    else
      @do_set null, a[0]


module.exports = cell = ->

  box = new Box

  # lazy. will eventually hold an array
  notifiers = undefined

  # the cell function that will be returned
  # ( closes over the above variables )
  # it takes one argument so that the function.length
  # of this cell is 1
  # this signals ( to some consumers ) that this is a read-write
  # cell
  f = ( x ) ->
    
    a = arguments

    # -- handle get()
    if a.length is 0
      # register invalidator
      if reactivity.active() then ( notifiers ?= [] ).push reactivity()
      # return
      return box.do_get()

    # -- handle different types of set()
    if box.do_set_auto.apply box, a # is true if value changes

      # call all accumulated notifiers
      if ( notifiers_ = notifiers )?
        notifiers = undefined # reset
        cb() for cb in notifiers_
    
    # setting a value does not return anything
    # this is part of the cell spec
    undefined

  # a read-only version of the cell
  f.immutable =  -> if arguments.length > 0 then throw new ReadOnlyError else f()
  f.callback = (e, r) -> f e, r
  f

cell.ReadOnlyError = ReadOnlyError