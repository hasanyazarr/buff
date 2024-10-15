# Animation
import plotly.graph_objects as go
import matplotlib.pyplot as plt

def animate(net, tracks):

    x = [n.pos[0] for n in net.nodes]
    y = [n.pos[1] for n in net.nodes]
    z = [n.pos[2] for n in net.nodes]

    fig = go.Figure(
        data=[
                go.Scatter3d(
                    x=x, y=y, z=z,
                    marker=dict(
                        size=4,
                        color=100,
                        colorscale='Viridis',
                    ),
                    line=dict(
                        color='darkblue',
                        width=2
                    )
                )
        ]*2,
        frames=[
            go.Frame(data=[
                        go.Scatter3d(
                                x=[bb[i][0]],
                                y=[bb[i][1]],
                                z=[bb[i][2]],
                                mode="markers",
                                marker=dict(color="red", size=10),
                        )
                    ]
            )
            for i in range(1, bb.shape[0])
        ]
    )

    fig.update_layout(
            title='BLEH',
            width=600,
            height=600,
            scene=dict(
                        xaxis=dict(range=[-10e-3, 10e-3], autorange=False),
                        yaxis=dict(range=[-2e-3,   2e-3], autorange=False),
                        zaxis=dict(range=[ 0e-3,  20e-3], autorange=False),
                        aspectratio=dict(x=1, y=1, z=1),
                        ),
            updatemenus = [
                {
                    "buttons": [
                        {
                            "args": [None],
                            "label": "&#9654;", # play symbol
                            "method": "animate",
                        },
                    ],
                    "direction": "left",
                    "pad": {"r": 10, "t": 70},
                    "type": "buttons",
                    "x": 0.1,
                    "y": 0,
                }
            ],
    )



    fig.show()



def animate2(net, tracks):

    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')
    x = [n.pos[0] for n in self.nodes]
    y = [n.pos[1] for n in self.nodes]
    z = [n.pos[2] for n in self.nodes]

    #ax.scatter(x,y,z)

    evel = np.array([e.nodes[0].pressure for e in self.edges])
    maxevel = min(evel)
    minevel = max(evel)

    for e in self.edges:
        x = np.array([e.nodes[0].pos[0], e.nodes[1].pos[0]])
        y = np.array([e.nodes[0].pos[1], e.nodes[1].pos[1]])
        z = np.array([e.nodes[0].pos[2], e.nodes[1].pos[2]])
        vel = (e.vel-minevel)/(maxevel-minevel)
        vel = (e.nodes[0].pressure-minevel)/(maxevel-minevel)
        ax.plot(x, y, z, color=plt.cm.jet(vel), linewidth=6)
    
    # set_axes_equal(ax)
    x_limits = ax.get_xlim3d()
    y_limits = ax.get_ylim3d()
    z_limits = ax.get_zlim3d()

    x_range = abs(x_limits[1] - x_limits[0])
    x_middle = np.mean(x_limits)
    y_range = abs(y_limits[1] - y_limits[0])
    y_middle = np.mean(y_limits)
    z_range = abs(z_limits[1] - z_limits[0])
    z_middle = np.mean(z_limits)

    # The plot bounding box is a sphere in the sense of the infinity
    # norm, hence I call half the max range the plot radius.
    plot_radius = 0.5*max([x_range, y_range, z_range])

    ax.set_xlim3d([x_middle - plot_radius, x_middle + plot_radius])
    ax.set_ylim3d([y_middle - plot_radius, y_middle + plot_radius])
    ax.set_zlim3d([z_middle - plot_radius, z_middle + plot_radius])



    plt.show()