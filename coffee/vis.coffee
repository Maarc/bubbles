# Note: "effort" has been replaced by "effort"

class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 940
    @height = 740

    @tooltip = CustomTooltip("gates_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @effort_centers = {
      "Low": {x: @width / 3, y: @height / 2},
      "Medium": {x: @width / 2, y: @height / 2},
      "High": {x: 2 * @width / 3, y: @height / 2}
    }
    @threat_centers = {
      "moderateLow": {x: @width / 3, y: 2*@height/3},
      "moderateMedium": {x: @width / 2, y: 2*@height/3},
      "moderateHigh": {x: 2 * @width / 3, y: 2*@height/3},
      "severeLow": {x: @width / 3, y: @height/2},
      "severeMedium": {x: @width / 2, y: @height/2},
      "severeHigh": {x: 2 * @width / 3, y: @height/2},
      "criticalLow": {x: @width / 3, y: @height/3} ,
      "criticalMedium": {x: @width / 2, y: @height/3},
      "criticalHigh": {x: 2 * @width / 3, y: @height/3}
    }

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.01
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # nice looking colors - no reason to buck the trend
    @fill_color = d3.scale.ordinal()
      .domain(["moderate", "severe", "critical"])
      .range(["#ffff26", "#ff8000", "#ff0000"])

    # use the max total_amount in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> parseInt(d.maximumThreatValue))
    @radius_scale = d3.scale.pow().exponent(1.7).domain([0, max_amount]).range([4, 35])

    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later

  create_nodes: () =>
    @data.forEach (d) =>
      node = {
        id: d.id
        radius: @radius_scale(parseInt(d.maximumThreatValue))
        value: d.maximumThreatValue
        name: d.gav
        application: d.applicationPublicId
        org: d.applicationPublicId
        group: d.threatLevel
        effort: d.effort
        x: Math.random() * @width
        y: Math.random() * @height
      }
      @nodes.push node

    @nodes.sort (a,b) -> b.value - a.value

  # create svg at #vis and then
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => @fill_color(d.group))
      .attr("stroke-width", 2)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
      .attr("id", (d) -> "bubble_#{d.id}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)


  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.hide_efforts()
    this.hide_threats()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  # sets the display of bubbles to be separated into each effort. Does this by calling move_towards_effort
  display_by_effort: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_effort(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.hide_threats()
    this.display_efforts()

  # sets the display of bubbles to be separated into each effort. Does this by calling move_towards_threat
  display_in_matrix: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_threat(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_efforts()
    this.display_threats()

  # move all circles to their associated @effort_centers
  move_towards_effort: (alpha) =>
    (d) =>
      target = @effort_centers[d.effort]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # move all circles to their associated @threat_centers
  move_towards_threat: (alpha) =>
    (d) =>
      #console.log d.group
      target = @threat_centers[d.group+d.effort]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1


  # Method to display effort titles
  display_efforts: () =>
    efforts_x = {"Low": 230, "Medium": @width / 2, "High": @width - 230}
    efforts_data = d3.keys(efforts_x)
    efforts = @vis.selectAll(".efforts")
      .data(efforts_data)

    efforts.enter().append("text")
      .attr("class", "efforts")
      .attr("x", (d) => efforts_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide effort titles
  hide_efforts: () =>
    efforts = @vis.selectAll(".efforts").remove()


  # Method to display effort titles
  display_threats: () =>
    threats_y = {"Critical": 180+40, "Severe": @height/2+40, "Moderate": @height-180+40}
    threats_data = d3.keys(threats_y)
    threats = @vis.selectAll(".threats")
      .data(threats_data)

    threats.enter().append("text")
      .attr("class", "threats")
      .attr("x", 45 )
      .attr("y", (d) => threats_y[d])
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide threat titles
  hide_threats: () =>
    threats = @vis.selectAll(".threats").remove()


  # displays details tooltip
  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Application:</span><span class=\"value\"> #{data.application}</span><br/>"
    content +="<span class=\"name\">Library:</span><span class=\"value\"> #{data.name}</span><br/>"
    content +="<span class=\"name\">Threat level:</span><span class=\"value\"> #{addCommas(data.value)}</span><br/>"
    content +="<span class=\"name\">Effort:</span><span class=\"value\"> #{data.effort}</span>"
    @tooltip.showTooltip(content,d3.event)

  # hides details tooltip
  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
    @tooltip.hideTooltip()


root = exports ? this

$ ->
  chart = null

  render_vis = (csv) ->
    chart = new BubbleChart csv
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()
  root.display_effort = () =>
    chart.display_by_effort()
  root.display_matrix = () =>
    chart.display_in_matrix()
  root.toggle_view = (view_type) =>
    if view_type == 'effort'
      root.display_effort()
    else if view_type == 'matrix'
      root.display_matrix()
    else
      root.display_all()

  d3.csv "data/data.csv", render_vis
